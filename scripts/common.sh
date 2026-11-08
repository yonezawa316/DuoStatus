#!/bin/sh
# Sourced by build/test scripts. No packages, global settings, or downloads.

prepare_build_environment() {
    build_dir="$project_root/build"
    mkdir -p "$build_dir/ModuleCache"
    # Swift driver temporary files must use the system's ASCII-safe directory.
    # Persistent module caches and all products remain inside this project.
    export TMPDIR="$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)"
    export CLANG_MODULE_CACHE_PATH="$build_dir/ModuleCache"
    sdk_path=${DUOSTATUS_SDK_PATH:-$(/usr/bin/xcrun --no-cache --sdk macosx --show-sdk-path)}
    swift_compiler=$(/usr/bin/xcrun --no-cache --find swiftc)
    clang_compiler=$(/usr/bin/xcrun --no-cache --find clang)
    deployment_target=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$project_root/Resources/Info.plist")
    swift_major=$("$swift_compiler" --version | /usr/bin/awk '/Swift version/ { split($4, version, "."); print version[1]; exit }')
    case "$swift_major" in
        ''|*[!0-9]*) echo "无法识别 Swift 编译器版本。" >&2; exit 1 ;;
    esac
    if [ "$swift_major" -lt 6 ]; then
        echo "构建需要 Swift 6 或更新版本；此脚本不会安装或更新工具。" >&2
        exit 1
    fi
    [ -d "$sdk_path" ] || { echo "macOS SDK 路径无效。" >&2; exit 1; }

    # New kernels distinguish pageable purgeable pages. Older SDKs do not name
    # that field; compile the fallback without referencing it in that case.
    memory_feature_flag=
    if printf '%s\n' '#include <mach/vm_statistics.h>' \
        'int main(void) { return (int)sizeof(((vm_statistics64_data_t *)0)->purgeable_pageable_count); }' \
        | "$clang_compiler" -isysroot "$sdk_path" -x c -fsyntax-only - >/dev/null 2>&1; then
        memory_feature_flag=DUOSTATUS_HAS_PAGEABLE_PURGEABLE
    fi
}
