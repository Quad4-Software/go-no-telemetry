#!/bin/sh
# Rename distpack outputs for GitHub release uploads.
set -eu

TAG=${1:?usage: package-release.sh TAG [output-dir]}
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
DIST="$ROOT/pkg/distpack"
OUT=${2:-"$ROOT/release"}

if [ ! -d "$DIST" ]; then
    echo "ERROR: missing $DIST (run make.bash -distpack first)" >&2
    exit 1
fi

mkdir -p "$OUT"
rm -f "$OUT"/go-no-telemtry-* "$OUT"/SHA256SUMS

for f in "$DIST"/*; do
    [ -f "$f" ] || continue
    base=$(basename "$f")

    case "$base" in
        *.src.tar.gz)
            cp "$f" "$OUT/go-no-telemtry-${TAG}.src.tar.gz"
            ;;
        *.linux-*.tar.gz|*.darwin-*.tar.gz|*.freebsd-*.tar.gz|*.aix-*.tar.gz)
            plat=$(echo "$base" | sed -E 's/^.*\.([a-z0-9]+-[a-z0-9]+)\.tar\.gz$/\1/')
            cp "$f" "$OUT/go-no-telemtry-${TAG}.${plat}.tar.gz"
            ;;
        *.windows-*.zip)
            plat=$(echo "$base" | sed -E 's/^.*\.([a-z0-9]+-[a-z0-9]+)\.zip$/\1/')
            cp "$f" "$OUT/go-no-telemtry-${TAG}.${plat}.zip"
            ;;
    esac
done

if ! ls "$OUT"/go-no-telemtry-* >/dev/null 2>&1; then
    echo "ERROR: no release artifacts produced in $OUT" >&2
    ls -la "$DIST" >&2 || true
    exit 1
fi

(
    cd "$OUT"
    sha256sum go-no-telemtry-* > SHA256SUMS
)

echo "Packaged release artifacts in $OUT:"
ls -la "$OUT"
