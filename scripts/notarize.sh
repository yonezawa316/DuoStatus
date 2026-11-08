#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
app_bundle="$project_root/dist/DuoStatus Release.app"
notary_dir="$project_root/build/Notarization"

# Run only when the owner explicitly chooses to submit this signed build to Apple.
# Store credentials in Keychain beforehand, never in this repo or the command line.
: "${NOTARY_PROFILE:?请设置已有钥匙串凭据的 NOTARY_PROFILE 名称。}"
"$project_root/scripts/verify.sh" "$app_bundle"
/usr/bin/codesign -d --verbose=4 "$app_bundle" 2>&1 | \
    /usr/bin/grep -q '^Authority=Developer ID Application:' || {
    echo "请先用已有 Developer ID Application 证书重新构建。" >&2
    exit 1
}
mkdir -p "$notary_dir"
rm -f "$notary_dir/submission.zip"
/usr/bin/ditto -c -k --keepParent --sequesterRsrc "$app_bundle" "$notary_dir/submission.zip"
/usr/bin/xcrun notarytool submit "$notary_dir/submission.zip" \
    --keychain-profile "$NOTARY_PROFILE" --wait --output-format plist \
    > "$notary_dir/result.plist"
notary_status=$(/usr/libexec/PlistBuddy -c 'Print :status' "$notary_dir/result.plist")
[ "$notary_status" = Accepted ] || {
    printf 'Apple 公证未获接受：%s。详情见 build/Notarization/result.plist。\n' "$notary_status" >&2
    exit 1
}
/usr/bin/xcrun stapler staple "$app_bundle"
"$project_root/scripts/package.sh" --notarized
