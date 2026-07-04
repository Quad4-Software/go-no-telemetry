# Fork overlay layout

This directory holds everything that makes this repo differ from upstream Go.
Upstream sync replays these files instead of hand-editing the tree.

## Layout

```
overlays/     Complete replacement files (mirror repo paths under here)
remove.txt    Upstream paths to delete (telemetry tests, bootstrap variants)
root/         Repo-root files (README, bootstrap.sh, CONTRIBUTING, .gitignore)
github/       GitHub issue templates and CI workflow
```

## When upstream changes telemetry

1. Sync: `./scripts/sync-upstream.sh`
2. If build fails, check which overlay files need updating
3. Edit files under `fork/overlays/` to match new upstream APIs
4. Run `./scripts/apply-fork.sh && ./scripts/verify-fork.sh`

## Design

Telemetry call sites in upstream `main.go` and tools are left unchanged.
`cmd/internal/telemetry` and `cmd/internal/telemetry/counter` are no-op stubs,
so new upstream `counter.Inc(...)` calls automatically do nothing.

Only files that must differ from upstream live in `overlays/` (~10 files)
instead of editing dozens of call sites on every sync.
