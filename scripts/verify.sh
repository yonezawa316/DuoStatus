#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
app_bundle=${1:-"$project_root/dist/DuoStatus Release.app"}
plist="$app_bundle/Contents/Info.plist"
binary="$app_bundle/Contents/MacOS/DuoStatusRelease"

/usr/bin/plutil -lint "$plist"
[ -x "$binary" ] || { echo "发布版可执行文件缺失。" >&2; exit 1; }
[ -s "$app_bundle/Contents/Resources/AppIcon.icns" ] || { echo "应用图标缺失。" >&2; exit 1; }
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")" = DuoStatusRelease ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = local.duostatus.release ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$plist")" = AppIcon ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$plist")" = true ]
minimum=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")
architectures=$(/usr/bin/lipo -archs "$binary")
case "$architectures" in
    'arm64 x86_64'|'x86_64 arm64') ;;
    *) printf '架构不完整或包含意外架构：%s\n' "$architectures" >&2; exit 1 ;;
esac
for architecture in arm64 x86_64; do
    binary_minimum=$(/usr/bin/otool -arch "$architecture" -l "$binary" | \
        /usr/bin/awk '$1 == "cmd" { in_build = ($2 == "LC_BUILD_VERSION") } in_build && $1 == "minos" { print $2; exit }')
    [ "$binary_minimum" = "$minimum" ] || {
        echo "$architecture 的最低系统 $binary_minimum 与 Info.plist 的 $minimum 不一致。" >&2
        exit 1
    }
    # Do not silently ship a binary that depends on a developer's local dylib.
    unexpected=$(/usr/bin/otool -arch "$architecture" -L "$binary" | \
        /usr/bin/awk '/compatibility version/ && $1 !~ /^\/System\/Library\// && $1 !~ /^\/usr\/lib\// { print $1 }')
    [ -z "$unexpected" ] || {
        printf '发现非系统动态库依赖：\n%s\n' "$unexpected" >&2
        exit 1
    }
done
/usr/bin/codesign --verify --strict --verbose=2 "$app_bundle"
printf '打包检查通过：arm64 + x86_64，macOS %s+，图标与签名有效。\n' "$minimum"
echo "这不是旧系统实机测试，也不代表已通过 Gatekeeper 公证检查。"
