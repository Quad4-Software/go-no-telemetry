# Contributing

This is a fork of [Go](https://go.dev/) with telemetry removed.

## Updating from upstream

Most maintenance is one command:

```sh
./scripts/sync-upstream.sh
```

If the rebase conflicts, recover with:

```sh
git rebase --abort
git reset --hard upstream/master
./scripts/apply-fork.sh
git add -A && git commit -m "Strip telemetry from Go fork"
```

Fork-specific changes live in `fork/overlays/` (source replacements) and
`fork/remove.txt` (paths to delete). Edit those when upstream changes
telemetry APIs, then run `./scripts/apply-fork.sh`.

## Pull requests

1. Build and verify: `./scripts/verify-fork.sh`
2. Do not reintroduce telemetry collection, uploads, or `GOTELEMETRY` settings.

## License

Same as Go. See [LICENSE](LICENSE).
