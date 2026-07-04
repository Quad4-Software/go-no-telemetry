#!/bin/sh
# Drop golang.org/x/telemetry from cmd/go vendor tree.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
CMDDIR="$ROOT/src/cmd"

log() { echo "[strip-vendor] $*" >&2; }

run_go() {
    if [ -x "$ROOT/bin/go" ]; then
        GOTOOLCHAIN=local "$ROOT/bin/go" "$@"
    elif command -v go >/dev/null 2>&1; then
        GOTOOLCHAIN=local go "$@"
    else
        return 127
    fi
}

cd "$CMDDIR"

if grep -q 'golang.org/x/telemetry' go.mod 2>/dev/null; then
    log "Removing golang.org/x/telemetry from go.mod..."
    if run_go mod edit -droprequire=golang.org/x/telemetry; then
        log "Refreshing vendor/..."
        if run_go mod vendor; then
            rm -rf vendor/golang.org/x/telemetry
            log "Done."
            exit 0
        fi
    fi
    log "go mod vendor unavailable; applying manual vendor strip..."
fi

rm -rf vendor/golang.org/x/telemetry
if [ -f vendor/modules.txt ]; then
    sed -i '/golang.org\/x\/telemetry/d' vendor/modules.txt
fi
if grep -q 'golang.org/x/telemetry' go.mod 2>/dev/null; then
    sed -i '/golang.org\/x\/telemetry/d' go.mod
fi

log "Done."
