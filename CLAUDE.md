# ioc-timing

The timing and delay-generator image of GEECS-BELLA's native EPICS IOCs:
epics-containers' `epics-base` developer image plus asyn R4-46 and
`epics-modules/delaygen` pinned to commit a2e58d7 (the R1-2-4 tag also
builds the module's example IOC, which does not build here). Details, the
patch and the driver's gaps: `README.md`.

- **Instances** live in GEECS-BELLA/geecs-epics, not here: `dgtest1` (SRS
  DG645 `U_DG645_BCaveBox2`, `hosts/htu-linux-camserv2`, profile `bench-dg`)
  and its fake twin `dgtest1-sim` (`hosts/sim`, profile `timing`).
- **Why ours.** No epics-containers image carries delaygen. Only the DG645
  driver is registered; the DG535 and the others join `delaygen.install.yml`
  when a device needs them.
- **Patch and switch.** `ibek-support-geecs/delaygen/dg645-init-clear-status.patch`:
  iocsh variable `DG645InitClearStatus`, C default 1 (upstream: `*CLS` at
  driver init, which clears status shared by every interface of the
  instrument); the `delaygen.DG645` entity's `clear_status_at_init` defaults
  to false, so a boot sends queries only.
- **Build.** On the IOC host: `docker build --target runtime -t ioc-timing:local ~/ioc-timing`.
  On a workstation: `DOCKER_DEFAULT_PLATFORM=linux/amd64 TARGET=runtime
  TAG=ioc-timing:local ./build` (the variable is required on Apple silicon; the
  image is amd64 and runs emulated).
- **Pins.** geecs-epics' compose file notes the commit the host image was
  built from. A bump: rebuild on the host (never during a run), update that
  note in the same change, recreate the container (`docker restart` keeps
  the old image), one IOC on the bench first.
- **Merging**: after a fresh-context review dispositioned on the PR, and the
  bench proof for anything that changes what reaches a device. Rules and
  program state: geecs-epics `CLAUDE.md`.
