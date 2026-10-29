# Generic IOC ioc-timing

Timing and delay generators on plain EPICS records, for GEECS (geecs-epics
decision 14: setpoint devices are plain records; decision 11: one image per
family). Built on epics-containers' `epics-base` developer image with the
template's iocStats, pvlogging and autosave, plus:

| Module | Version | Source | Reuse (decision 10) |
|---|---|---|---|
| asyn | R4-46 | upstream ibek-support recipe | tier 1, dependency |
| delaygen | a2e58d7 (master, 2026-08; R1-2-4 + the IOC moved out + `%.11e` write formats) | [epics-modules/delaygen](https://github.com/epics-modules/delaygen) (APS BCDA; synApps licence) | tier 1, dependency, with one build-time patch (below) |

`delaygen` also carries the DG535 (GPIB), Colby PDL100A and Coherent SDG
support; only the DG645 driver is registered (`drvAsynDG645.dbd`). The
others join `delaygen.install.yml`'s `dbds` when a device needs them. The
pin is a commit, not the R1-2-4 tag, because the tag's `src/Makefile` also
builds the module's example IOC, whose dbd needs calc's `sseq` record and
StreamDevice; upstream moved that IOC out afterwards (`delaygen.install.yml`).

## Build

No vendor code is inside, so the image is published: CI builds on every push
and, on a git tag (CalVer `YYYY.M.N`, never re-pushed), pushes
`ghcr.io/geecs-bella/ioc-timing-runtime:<tag>` and
`ghcr.io/geecs-bella/ioc-timing-developer:<tag>`, and the release job attaches the
ioc schema and `versions.json` to the GitHub release. Both packages are made
public once, by hand, after the first tag creates them (ghcr creates them
private); from then hosts pull with no credentials. Hosts never build. A
pre-release tag (`2026.10.2b1`) publishes a branch for bench work.

A local build, for development only:

```
DOCKER_DEFAULT_PLATFORM=linux/amd64 TARGET=runtime TAG=ioc-timing:local ./build  # amd64, emulated on Apple silicon
```

The compose files in geecs-epics pin `ghcr.io/geecs-bella/ioc-timing-runtime:<tag>`;
a bump is a new tag here and one line there.

## DG645

`drvAsynDG645` is an asyn port driver over an asyn octet port (the DG645's
raw-socket interface, TCP 5025, or its RS-232 port behind a terminal server),
with `drvDG645.db` on top: per delay channel A to H the reference channel
and the delay (`DLAY?c`, read as the pair `d,t`), per output T0, AB, CD, EF,
GH the amplitude, offset and polarity (`LAMP?b`, `LOFF?b`, `LPOL?b`), the
trigger source, level, rate, inhibit, holdoff and prescalers, burst mode,
the interface configuration, and the status word the driver keeps from
`LERR?`. The ibek entity, in
`ibek-support-geecs/delaygen/delaygen.ibek.support.yaml`:

- `delaygen.DG645` — the IP port (`<name>_IP`, CR LF in, LF out), the
  driver and the database under `P` + `R`; `clear_status_at_init` (below)
  and `trace` (every byte on the console from before the first query).

### What the stock driver sends at start, and the patch

Read in the sources before anything ran (`drvAsynDG645.cpp`,
`drvDG645.db`, asyn's `devAsynFloat64.c` / `devAsynInt32.c`):

1. `drvAsynDG645()` (iocsh, before iocInit) sends `*IDN?`, `LERR?` and
   then **`*CLS`**. `*CLS` is a write: it clears the instrument's standard
   event status register, its instrument status register and its error
   queue, which are shared by every interface of the instrument, so a
   LabVIEW device or an operator reading them loses what was there.
2. At iocInit every readback record has `PINI YES` and sends its query; the
   output records read the device at init too (asyn's `initAo`,
   `initBo`/`initMbbo`/`initLo` "Read the current value from the device"),
   again queries. The delay setpoints are synchronised from the readbacks
   through a `seq` that disables the writer record first
   (`$(P)$(R)<c>DelaySeq`), so no delay is written back at boot.
3. After iocInit nothing is sent until a record processes: every readback
   is `SCAN Passive` and the driver has no poller, so a setting changed from
   the front panel or another interface is not seen until a record is
   processed (`caput <pv>.PROC 1`, or a `SCAN` set after boot).

`LERR?` is a query by form but pops one entry from the instrument's single
error queue; `*ESR?` and `INSR?` (the `EventStatusLI` record, not read at
boot) clear on read. They are left as upstream has them.

`dg645-init-clear-status.patch` (applied by `delaygen.install.yml` on
upstream a2e58d7; it also applies to the R1-2-4 tag) adds one
iocsh variable, defaulting to upstream's behaviour, declared in
`drvAsynDG645.dbd` so that iocsh's `var` can set it (without the
`variable()` line `var` prints "No known var" and the stock behaviour runs):

| Variable | 1 (upstream) | 0 |
|---|---|---|
| `DG645InitClearStatus` | `*CLS` after `*IDN?` and `LERR?` at driver init | no `*CLS`: initialisation is `*IDN?` and `LERR?` only |

The `DG645.clear_status_at_init` parameter renders it and **defaults to
false**: in GEECS the first DG645s are ported read-only while their LabVIEW
devices stay the production path, and an IOC start must leave the
instrument's status alone. With it false, a boot sends the instrument
nothing but queries, checked against the protocol fake in geecs-epics
(`sim/dg645_sim.py`, which logs any non-query as `WRITE`). Two other `*CLS`
paths exist and are not reached in a read-only instance: the
`StatusCheckingBO` record sends one when a client re-enables status
checking (the access file refuses every put), and `StatusClearBO` is a
client's explicit request. The change is worth proposing upstream (an
optional `*CLS`); until then it lives here.

### Known gaps in the upstream driver (a2e58d7)

- **No poll.** See item 3 above: readbacks are the boot reading until a
  record is processed.
- **Status PV semantics.** `StatusLI` is the last `LERR?` the driver read,
  updated only after the driver's own writes (status checking "at the
  driver level"), not a poll of the instrument's error queue.

### Testing without hardware

geecs-epics `hosts/sim/compose.yaml` (profile `timing`) runs this image
against the DG645 fake on the real `dgtest1` config, with the fake's log as
the transcript of what the IOC sent.

## Licence

GEECS's own work here (the Dockerfile changes, the ibek support files and
patches under `ibek-support-geecs/`, the docs) is under `LICENSE`, the GEECS
licence: BSD-style, Copyright The Regents of the University of California,
through Lawrence Berkeley National Laboratory, as in GEECS-Plugins. The files
generated from epics-containers' ioc-template keep its Apache-2.0 licence,
`LICENSE-ioc-template`. The EPICS modules the image builds (fetched at build
time, not vendored) carry their own licences, listed in the table above.

## Template Info
This repository was generated by
[ioc-template](https://github.com/epics-containers/ioc-template) 4.8.0
(`copier update -a --trust .` to update). The devcontainer and `./build`
work as in every epics-containers generic IOC; the IOC binary links
`$(SUPPORT)/delaygen` through `ibek`.
