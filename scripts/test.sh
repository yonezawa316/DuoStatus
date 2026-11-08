#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$project_root/scripts/common.sh"
prepare_build_environment
mkdir -p "$build_dir/Tests"
architecture=$(/usr/bin/uname -m)
case "$architecture" in arm64|x86_64) ;; *) echo "仅支持 Mac 主机。" >&2; exit 1 ;; esac

# Discover focused test executables; never launch the menu bar app or a sampler.
for test_source in "$project_root"/Tests/*Tests.swift; do
    test_name=$(/usr/bin/basename "$test_source" .swift)
    set -- -swift-version 6 -O -target "$architecture-apple-macosx$deployment_target" \
        -sdk "$sdk_path" -module-cache-path "$build_dir/ModuleCache" \
        -framework AppKit -framework IOKit -framework CoreWLAN -framework SystemConfiguration
    if [ -n "$memory_feature_flag" ]; then
        set -- "$@" -D "$memory_feature_flag"
    fi
    for source in "$project_root"/Sources/*.swift; do
        case "$source" in */main.swift) ;; *) set -- "$@" "$source" ;; esac
    done
    "$swift_compiler" "$@" "$test_source" -o "$build_dir/Tests/$test_name"
    "$build_dir/Tests/$test_name"
done
