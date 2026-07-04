#!/bin/sh
# Check out upstream Go <version>, apply no-telemetry overlays, and build the toolchain.
# Usage: build-version.sh <version>
#   version: e.g. 1.26.4 or go1.26.4
# Requires GOROOT_BOOTSTRAP (Go 1.24.6+).
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

VERSION="${1:?version required}"
VERSION="${VERSION#go}"
VERSION="${VERSION#v}"
UPSTREAM_TAG="go${VERSION}"
FORK_META_REF="${FORK_META_REF:-origin/master}"

log() { echo "[build-version] $*" >&2; }

if [ ! -d "$ROOT/fork/overlays" ]; then
    log "ERROR: missing fork overlays; run from go-no-telemetry checkout"
    exit 1
fi

if ! git remote | grep -qx upstream; then
    git remote add upstream https://go.googlesource.com/go
fi

if ! git rev-parse "$FORK_META_REF" >/dev/null 2>&1; then
    log "ERROR: fork metadata ref '$FORK_META_REF' not found"
    exit 1
fi
FORK_SHA="$(git rev-parse "$FORK_META_REF")"

log "Fetching upstream ${UPSTREAM_TAG}..."
git fetch upstream "refs/tags/${UPSTREAM_TAG}:refs/tags/${UPSTREAM_TAG}" 2>/dev/null \
    || git fetch upstream tag "${UPSTREAM_TAG}" --no-tags

log "Checking out ${UPSTREAM_TAG}..."
git checkout -f "$UPSTREAM_TAG"

log "Restoring fork metadata from ${FORK_META_REF}..."
git checkout "$FORK_SHA" -- fork scripts bootstrap.sh LICENSE PATENTS go.env .gitignore codereview.cfg

"$ROOT/scripts/apply-fork.sh"

# env.go overlay tracks newer upstream; keep the native file for this Go release.
if git cat-file -e "${UPSTREAM_TAG}:src/cmd/go/internal/envcmd/env.go" 2>/dev/null; then
    git checkout "$UPSTREAM_TAG" -- src/cmd/go/internal/envcmd/env.go
fi

printf 'go%s\ntime %s\n' "$VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > VERSION

BOOTSTRAP="${GOROOT_BOOTSTRAP:?set GOROOT_BOOTSTRAP to a Go 1.24.6+ toolchain}"
log "Building with GOROOT_BOOTSTRAP=$BOOTSTRAP"
(
    cd "$ROOT/src"
    export GOROOT_BOOTSTRAP="$BOOTSTRAP"
    export GOTOOLCHAIN=local
    export CGO_ENABLED=0
    ./make.bash
)

if [ "$( "$ROOT/bin/go" telemetry)" != "off" ]; then
    log "ERROR: go telemetry is not off"
    exit 1
fi

GO_VER=$("$ROOT/bin/go" version | awk '{print $3}')
case "$GO_VER" in
    go${VERSION}*) log "Built $("$ROOT/bin/go" version)" ;;
    *)
        log "ERROR: expected go${VERSION}, got ${GO_VER}"
        exit 1
        ;;
esac
