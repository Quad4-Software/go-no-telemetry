# go no telemetry

[![CI](https://github.com/Quad4-Software/go-no-telemtry/actions/workflows/ci.yml/badge.svg)](https://github.com/Quad4-Software/go-no-telemtry/actions/workflows/ci.yml)

A fork of the Go programming language with all telemetry stripped.

No counter data is collected. No uploads are sent. The `go telemetry` command is
a stub that always reports `off`. The `GOTELEMETRY` and `GOTELEMETRYDIR`
environment variables have been removed. Telemetry hooks in the toolchain call
no-op stubs, so upstream `main.go` and tool entry points stay unchanged.

## Quick start

```sh
export PATH="$HOME/.gonot/bin:$PATH"
./bootstrap.sh install my-fork
go version
```

## Building

### Quick build (requires Go 1.24.6 or later)

```sh
cd src
GOROOT_BOOTSTRAP=/path/to/go1.24.6 ./make.bash
```

### Full bootstrap from source

```sh
./bootstrap.sh prefetch          # one-time download
./bootstrap.sh build --offline   # clang -> go1.4 -> ... -> fork
```

## Updating from upstream Go

```sh
./scripts/sync-upstream.sh
```

This fetches [upstream Go](https://go.googlesource.com/go), rebases onto
`upstream/master`, and re-applies the no-telemetry overlays from `fork/`.

If the rebase conflicts:

```sh
git rebase --abort
git reset --hard upstream/master
./scripts/apply-fork.sh
git add -A && git commit -m "Strip telemetry from Go fork"
./scripts/verify-fork.sh
```

To refresh overlays after editing `fork/overlays/`:

```sh
./scripts/apply-fork.sh
./scripts/verify-fork.sh
```

## Version manager

See `./bootstrap.sh --help`. Installed versions live under `~/.gonot/versions/`.

| Command | Description |
|---------|-------------|
| `install <name>` | Build and register a named version |
| `use <name>` | Switch active version |
| `update` | Rebuild the active version |
| `list` | Show installed versions |

Add to your shell profile:

```sh
export PATH="$HOME/.gonot/bin:$PATH"
```

## Project structure

```
bootstrap.sh          Build script and version manager
fork/overlays/        No-telemetry source replacements (reapplied on sync)
fork/remove.txt       Upstream telemetry files to delete on sync
scripts/              sync-upstream.sh, apply-fork.sh, verify-fork.sh
src/                  Go standard library and toolchain
```

## CI

GitHub Actions builds with Go 1.24.6 bootstrap and verifies telemetry is off.
See [.github/workflows/ci.yml](.github/workflows/ci.yml).

## Releases

Push a version tag to publish platform binaries.
See [.github/workflows/release.yml](.github/workflows/release.yml).

Offline kits are built locally only: `./scripts/make-offline-bundle.sh --tag v1.27.0 --releases ./release`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Same as Go. See [LICENSE](LICENSE).
