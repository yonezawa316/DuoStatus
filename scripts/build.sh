#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$project_root/scripts/common.sh"
prepare_build_environment
app_bundle="$project_root/dist/DuoStatus Release.app"
staging_bundle="$build_dir/Staging/DuoStatus Release.app"

# The personal DuoStatus executable has a different name and is never stopped.
if /usr/bin/pgrep -x DuoStatusRelease >/dev/null; then
    echo "请先退出 DuoStatus Release，再重新构建发布版。" >&2
    exit 1
fi

/usr/bin/plutil -lint "$project_root/Resources/Info.plist"
[ -s "$project_root/Resources/AppIcon.icns" ] || {
    echo "缺少 Resources/AppIcon.icns，请先生成或恢复应用图标。" >&2
    exit 1
}
mkdir -p "$build_dir/Binaries" "$project_root/dist"
for architecture in arm64 x86_64; do
    set -- -swift-version 6 -Osize -whole-module-optimization \
        -target "$architecture-apple-macosx$deployment_target" -sdk "$sdk_path" \
        -module-cache-path "$build_dir/ModuleCache" \
        -framework AppKit -framework IOKit -framework CoreWLAN \
        -framework SystemConfiguration -module-name DuoStatusRelease
    if [ -n "$memory_feature_flag" ]; then
        set -- "$@" -D "$memory_feature_flag"
    fi
    "$swift_compiler" "$@" "$project_root"/Sources/*.swift \
        -o "$build_dir/Binaries/DuoStatusRelease-$architecture"
done

# Only remove fixed, project-owned generated paths. Do not touch the personal app.
rm -rf "$staging_bundle"
mkdir -p "$staging_bundle/Contents/MacOS" "$staging_bundle/Contents/Resources"
/usr/bin/lipo -create "$build_dir/Binaries/DuoStatusRelease-arm64" \
    "$build_dir/Binaries/DuoStatusRelease-x86_64" \
    -output "$staging_bundle/Contents/MacOS/DuoStatusRelease"
chmod 755 "$staging_bundle/Contents/MacOS/DuoStatusRelease"
/usr/bin/install -m 644 "$project_root/Resources/Info.plist" "$staging_bundle/Contents/Info.plist"
/usr/bin/install -m 644 "$project_root/Resources/AppIcon.icns" "$staging_bundle/Contents/Resources/AppIcon.icns"

if [ -n "${SIGNING_IDENTITY:-}" ]; then
    case "$SIGNING_IDENTITY" in
        'Developer ID Application:'*) ;;
        *) echo "SIGNING_IDENTITY 必须是已有的 Developer ID Application 证书名称。" >&2; exit 1 ;;
    esac
    /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime \
        --timestamp "$staging_bundle"
else
    /usr/bin/codesign --force --sign - --timestamp=none "$staging_bundle"
fi
"$project_root/scripts/verify.sh" "$staging_bundle"
rm -rf "$app_bundle"
mv "$staging_bundle" "$app_bundle"
printf '已构建 Universal 应用：%s\n' "$app_bundle"
if [ -z "${SIGNING_IDENTITY:-}" ]; then
    echo "当前是 ad-hoc 本地签名预发布版，尚未经过 Apple 公证。"
fi
