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

Prebuilt binaries are published on [GitHub Releases](https://github.com/Quad4-Software/go-no-telemtry/releases)
when a version tag is pushed:

```sh
git tag v1.27.0
git push origin v1.27.0
```

The [Release workflow](.github/workflows/release.yml) builds for:

| Platform | Archive |
|----------|---------|
| Linux amd64 | `go-no-telemtry-vX.Y.Z.linux-amd64.tar.gz` |
| Linux arm64 | `go-no-telemtry-vX.Y.Z.linux-arm64.tar.gz` |
| macOS amd64 | `go-no-telemtry-vX.Y.Z.darwin-amd64.tar.gz` |
| macOS arm64 | `go-no-telemtry-vX.Y.Z.darwin-arm64.tar.gz` |
| Windows amd64 | `go-no-telemtry-vX.Y.Z.windows-amd64.zip` |

Each release includes platform binaries, a source tarball, and `SHA256SUMS`.
To install, extract the archive for your platform and add `go/bin` to your `PATH`.

Manual release trigger: Actions -> Release -> Run workflow.

### Offline kit (local only)

Build them locally for air-gapped installs (USB transfer, etc.):

| Contents | Purpose |
|----------|---------|
| `source/` | Fork source tree |
| `bootstrap-tars/` | Upstream Go sources (go1.4 through go1.24.6) |
| `bootstrap-bin/` | Official Go 1.24.6 binaries per platform |
| `releases/` | Prebuilt go-no-telemtry binaries (copy from `./release/` after a local build) |

**Create locally (connected machine):**

```sh
./bootstrap.sh prefetch
./scripts/make-offline-bundle.sh --tag v1.27.0 --releases ./release
```

**Use on air-gapped machine:**

Linux / macOS / Git Bash:

```sh
unzip go-no-telemtry-offline-v1.27.0.zip
cd go-no-telemtry-offline-v1.27.0
./install-offline-kit.sh verify
./install-offline-kit.sh prebuilt prod
export PATH="$HOME/.gonot/bin:$PATH"
go telemetry   # off
```

Windows:

```bat
REM Right-click the .zip -> Extract All, or:
powershell -Command "Expand-Archive -Path go-no-telemtry-offline-v1.27.0.zip -DestinationPath ."
cd go-no-telemtry-offline-v1.27.0
Setup.bat
```

Double-click `Setup.bat` for a graphical wizard (prebuilt or build from source).
Or use `install-offline-kit.bat` from the command line.

Then add `%USERPROFILE%\.gonot\bin` to your PATH (the wizard can do this automatically).

**Optional:** On a connected Windows PC with [Inno Setup 6](https://jrsoftware.org/isinfo.php),
build a single `Setup.exe` for the USB:

```powershell
.\scripts\build-windows-installer.ps1 -KitDir path\to\extracted-kit
```

## License

Same as Go. See [LICENSE](LICENSE).
