#!/bin/sh
# Build the fork and verify telemetry is disabled.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

log() { echo "[verify-fork] $*" >&2; }

if [ "${SKIP_BUILD:-0}" != "1" ]; then
    BOOTSTRAP=""
    if [ -x "$ROOT/bin/go" ]; then
        candidate=$(GOTOOLCHAIN=local "$ROOT/bin/go" env GOROOT 2>/dev/null || true)
        if [ -n "$candidate" ] && [ "$candidate" != "$ROOT" ]; then
            BOOTSTRAP=$candidate
        fi
    fi
    if [ -z "$BOOTSTRAP" ] && [ -d /usr/lib/go ]; then
        BOOTSTRAP=/usr/lib/go
    fi
    if [ -z "$BOOTSTRAP" ] && command -v go >/dev/null 2>&1; then
        BOOTSTRAP=$(GOTOOLCHAIN=local go env GOROOT 2>/dev/null || true)
    fi
    if [ -z "$BOOTSTRAP" ]; then
        log "ERROR: no bootstrap Go found (set SKIP_BUILD=1 to skip)"
        exit 1
    fi
    log "Building toolchain (GOROOT_BOOTSTRAP=$BOOTSTRAP)..."
    (
        cd "$ROOT/src"
        GOROOT_BOOTSTRAP="$BOOTSTRAP"
        export GOROOT_BOOTSTRAP
        ./make.bash
    )
fi

GO="$ROOT/bin/go"
if [ ! -x "$GO" ]; then
    log "ERROR: $GO not found"
    exit 1
fi

log "Checking telemetry..."
test "$("$GO" telemetry)" = "off"
"$GO" telemetry on 2>&1 | grep -q 'telemetry is disabled'

if "$GO" env GOTELEMETRY 2>/dev/null | grep -q .; then
    log "ERROR: GOTELEMETRY should not be set"
    exit 1
fi

log "OK"
