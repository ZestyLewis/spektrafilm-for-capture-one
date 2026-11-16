# Project continuity

Read `HANDOVER.md` and `qa/AUDIT-FIX-STATUS.json` before starting work. They distinguish the installed/tested runtime from later documentation commits and list remaining audit work.

- Preserve the user's no-round-trip requirement, native control behavior, original images, high-depth export and durable per-movement edits.
- Prefer code, APIs and command-line fixtures. Use desktop automation only when necessary. Use disposable catalogs for host tests and verified backups before fundamental installed/state changes.
- Keep the exact supported-host gate until another host passes an explicit capability matrix. Removing the gate is not compatibility support.
- At each meaningful implementation/test/deployment milestone, update the affected task's status, completed substeps, evidence and remaining work in `qa/AUDIT-FIX-STATUS.json`. Update `HANDOVER.md` when resume instructions or delivery state changes.
- `implemented` means the ledger's bounded primary fix; it does not automatically close its parent or all acceptance tests. Do not mark partial/unverified work complete. Preserve historical audit evidence separately from current status.
- Keep source HEAD, tested runtime, packaged runtime, installed runtime, PR/CI and public release states explicit. Never infer one from another or hand-edit manifests to claim an unperformed build.
- On Luka's workspace, synchronize the sibling `Audit-2026-11-16` task overlays using its `sync-implementation-status.py`, then refresh its audit archive if those files changed. Do not overwrite unrelated user work.
- One writer owns each shared file or agreed region. Coordinate edits to `SpatialPreview.cs` and `SpektraFilmTool.cs`; retain working backups and upstream notices.
