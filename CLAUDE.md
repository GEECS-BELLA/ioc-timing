# ioc-timing

The timing and delay-generator image of GEECS-BELLA's native EPICS IOCs:
epics-containers' `epics-base` developer image plus asyn R4-46 and
`epics-modules/delaygen` pinned to commit a2e58d7 (the R1-2-4 tag also
builds the module's example IOC, which does not build here). Details, the
patch and the driver's gaps: `README.md`.

- **Instances** live in GEECS-BELLA/geecs-epics, not here: `dgtest1` (SRS
  DG645 `U_DG645_BCaveBox2`, profile `bench-dg`)
  and its fake twin `dgtest1-sim` (`hosts/sim`, profile `timing`).
- **Why ours.** No epics-containers image carries delaygen. Only the DG645
  driver is registered; the DG535 and the others join `delaygen.install.yml`
  when a device needs them.
- **Patch and switch.** `ibek-support-geecs/delaygen/dg645-init-clear-status.patch`:
  iocsh variable `DG645InitClearStatus`, C default 1 (upstream: `*CLS` at
  driver init, which clears status shared by every interface of the
  instrument); the `delaygen.DG645` entity's `clear_status_at_init` defaults
  to false, so a boot sends queries only.
- **Images.** CI publishes on a git tag, CalVer `YYYY.M.N` (`2026.10.1`;
  never re-push a tag): `ghcr.io/geecs-bella/ioc-timing-runtime:<tag>` (public;
  what hosts pull, no credentials) and `-developer` (the release job runs in
  it; a build base). Hosts never build. Bench work from a branch: a
  pre-release tag (`2026.10.2b1`). A local build for development:
  `DOCKER_DEFAULT_PLATFORM=linux/amd64 TARGET=runtime TAG=ioc-timing:local ./build`
  (the variable is required on Apple silicon; the image is amd64, emulated).
- **Pins.** geecs-epics' compose files pin the tag. A bump: tag here, change
  the tag in compose in one geecs-epics PR, `docker compose pull <service>`
  and recreate on the host (`docker restart` keeps the old image), one IOC
  on the bench first. Rollback: revert that compose change and recreate.
- **Merging**: after a fresh-context review dispositioned on the PR, and the
  bench proof for anything that changes what reaches a device. Rules and
  program state: geecs-epics `CLAUDE.md`.
