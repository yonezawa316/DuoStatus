#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
icon_build="$project_root/build/Icon"
mkdir -p "$icon_build" "$project_root/build/ModuleCache" "$project_root/docs/assets"
# The installed Swift driver requires an ASCII path for its short-lived files.
export TMPDIR="$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)"
export CLANG_MODULE_CACHE_PATH="$project_root/build/ModuleCache"

sdk_path=$(/usr/bin/xcrun --no-cache --sdk macosx --show-sdk-path)
swift_compiler=$(/usr/bin/xcrun --no-cache --find swiftc)
"$swift_compiler" -swift-version 6 -O -sdk "$sdk_path" -framework AppKit \
    -module-cache-path "$project_root/build/ModuleCache" \
    "$project_root/scripts/IconArtwork.swift" -o "$icon_build/GenerateAppIcons"
"$icon_build/GenerateAppIcons" "$icon_build" "$project_root/docs/assets"
/usr/bin/iconutil -c icns "$icon_build/AppIcon-light.iconset" -o "$project_root/Resources/AppIcon.icns"
/usr/bin/iconutil -c icns "$icon_build/AppIcon-dark.iconset" -o "$project_root/Resources/AppIcon-Dark.icns"
printf '应用图标已生成：Resources/AppIcon.icns（浅色）、Resources/AppIcon-Dark.icns（深色）\n'
