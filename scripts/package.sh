#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
app_bundle="$project_root/dist/DuoStatus Release.app"
output_dir="$project_root/dist"
output_dir_set=false
notarized=false

usage() {
    echo "用法：./scripts/package.sh [--notarized] [--output-dir PATH]"
    echo "默认输出到工程 dist/；PATH 必须是已有目录，相对路径按当前工作目录解析。"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --notarized) notarized=true; shift ;;
        --output-dir)
            if [ "$#" -lt 2 ] || [ -z "$2" ] || [ "$output_dir_set" = true ]; then
                usage >&2
                exit 1
            fi
            case "$2" in --*) usage >&2; exit 1 ;; esac
            output_dir=$2
            output_dir_set=true
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done

[ -d "$output_dir" ] || { echo "输出目录不存在；请指定已有目录。" >&2; exit 1; }
output_dir=$(CDPATH= cd -- "$output_dir" && pwd -P)
case "$output_dir/" in
    *.[aA][pP][pP]/*) echo "不能把分享包写入应用包内部。" >&2; exit 1 ;;
esac

"$project_root/scripts/verify.sh" "$app_bundle"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_bundle/Contents/Info.plist")
case "$version" in ''|*[!0-9A-Za-z.-]*) echo "版本号不适合用于文件名。" >&2; exit 1 ;; esac
signature=$(/usr/bin/codesign -d --verbose=4 "$app_bundle" 2>&1)
case "$notarized" in
    false)
        if printf '%s\n' "$signature" | /usr/bin/grep -q '^Signature=adhoc$'; then
            signing_label=adhoc
        else
            printf '%s\n' "$signature" | /usr/bin/grep -q '^Authority=Developer ID Application:' || {
                echo "只支持 ad-hoc 或 Developer ID Application 签名。" >&2; exit 1;
            }
            signing_label=developer-id-unnotarized
        fi
        ;;
    true)
        printf '%s\n' "$signature" | /usr/bin/grep -q '^Authority=Developer ID Application:' || {
            echo "公证包必须使用 Developer ID Application 签名。" >&2; exit 1;
        }
        /usr/bin/xcrun stapler validate "$app_bundle"
        /usr/sbin/spctl --assess --type execute --verbose=2 "$app_bundle"
        signing_label=notarized
        ;;
esac

archive_name="DuoStatus-$version-universal-$signing_label.zip"
archive="$output_dir/$archive_name"
checksum="$archive.sha256"
for destination in "$archive" "$checksum"; do
    if [ -L "$destination" ] || { [ -e "$destination" ] && [ ! -f "$destination" ]; }; then
        printf '拒绝覆盖符号链接或非普通文件：%s\n' "$destination" >&2
        exit 1
    fi
done

# Prepare both files inside the project before replacing named export artifacts.
mkdir -p "$project_root/build"
package_dir=$(/usr/bin/mktemp -d "$project_root/build/Package.XXXXXX")
trap 'rm -rf "$package_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
temporary_archive="$package_dir/$archive_name"
# Ad-hoc previews need no local extended attributes. Exclude provenance and
# Finder metadata from public downloads while keeping executable permissions.
# Notarized builds preserve ticket metadata; validate after extracting as well.
if [ "$signing_label" = notarized ]; then
    /usr/bin/ditto -c -k --keepParent --sequesterRsrc "$app_bundle" "$temporary_archive"
else
    /usr/bin/ditto -c -k --keepParent --norsrc --noextattr "$app_bundle" "$temporary_archive"
fi

# This optional build-time helper changes only the ZIP's Finder metadata, not
# its data or the embedded application. A headless CI host may reject the icon.
mkdir -p "$project_root/build/Tools" "$project_root/build/ModuleCache"
if icon_swift_compiler=$(/usr/bin/xcrun --no-cache --find swiftc) &&
   icon_sdk_path=$(/usr/bin/xcrun --no-cache --sdk macosx --show-sdk-path) &&
   icon_tmpdir=$(/usr/bin/getconf DARWIN_USER_TEMP_DIR) &&
   TMPDIR="$icon_tmpdir" CLANG_MODULE_CACHE_PATH="$project_root/build/ModuleCache" \
       "$icon_swift_compiler" -swift-version 6 -O -sdk "$icon_sdk_path" \
       -module-cache-path "$project_root/build/ModuleCache" -framework AppKit \
       "$project_root/scripts/SetArchiveIcon.swift" \
       -o "$project_root/build/Tools/SetArchiveIcon" &&
   "$project_root/build/Tools/SetArchiveIcon" \
       "$project_root/Resources/AppIcon.icns" "$temporary_archive"; then
    :
else
    echo "警告：未能设置 ZIP 的 Finder 外观图标；应用内置图标和分享包内容不受影响。" >&2
fi

(cd "$package_dir" && /usr/bin/shasum -a 256 "$archive_name" > "$archive_name.sha256")
/bin/mv -f "$temporary_archive" "$archive"
/bin/mv -f "$temporary_archive.sha256" "$checksum"
printf '分享包：%s\n校验文件：%s.sha256\n' "$archive" "$archive"
