#!/bin/sh
# Shared platform detection for offline kit scripts.
detect_platform() {
    _os=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')
    _arch=$(uname -m 2>/dev/null)
    case "$_os" in
        linux) goos=linux ;;
        darwin) goos=darwin ;;
        mingw*|msys*|cygwin*|windows*) goos=windows ;;
        *) goos="$_os" ;;
    esac
    case "$_arch" in
        x86_64|amd64) goarch=amd64 ;;
        aarch64|arm64) goarch=arm64 ;;
        i686|i386) goarch=386 ;;
        *) goarch="$_arch" ;;
    esac
    echo "${goos}-${goarch}"
}

bundled_bootstrap_root() {
    bundle_root=$1
    plat=${2:-$(detect_platform)}
    root="$bundle_root/bootstrap-bin/${plat}/go"
    if [ -x "$root/bin/go" ] || [ -f "$root/bin/go.exe" ]; then
        echo "$root"
        return 0
    fi
    return 1
}

find_release_archive() {
    releases_dir=$1
    tag=$2
    plat=${3:-$(detect_platform)}
    goos=${plat%-*}
    goarch=${plat#*-}
    for f in \
        "$releases_dir/go-no-telemtry-${tag}.${plat}.tar.gz" \
        "$releases_dir/go-no-telemtry-${tag}.${plat}.zip"
    do
        if [ -f "$f" ]; then
            echo "$f"
            return 0
        fi
    done
    return 1
}
