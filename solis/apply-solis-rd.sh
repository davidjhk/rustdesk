#!/bin/bash
# Turns a clean RustDesk source tree into SOLIS RD.
#
#   apply-solis-rd.sh <rustdesk-source-dir>
#
# Re-run it on every new upstream tag: it is the whole difference between
# RustDesk and SOLIS RD, so taking an upstream security fix means checking out
# the new tag, running this, and rebuilding. Every edit is checked; if upstream
# moves a line this script expects, it stops instead of building a half-branded
# client.
set -euo pipefail

SRC="${1:?usage: $0 <rustdesk-source-dir>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ICONS="$HERE/icons"

# A space breaks RustDesk's macOS service: the launchd plist runs the app path
# through `sh -c` unquoted. Keep the internal name free of spaces.
APP_NAME="${SOLIS_APP_NAME:-SOLIS-RD}"
BUNDLE_ID="com.solisenginc.solisrd"
RENDEZVOUS="relay.solisenginc.com"
PUBKEY="O5oDDrwRUbhw6ug39OW71yN9Z4BXZMuENcDMobhZJgY="

case "$APP_NAME" in *[!A-Za-z0-9_-]*) echo "APP_NAME must be letters, digits, - or _" >&2; exit 1;; esac

# replace FILE OLD NEW: literal replace, fails if OLD is not there.
replace() {
  python3 -I - "$@" <<'PY'
import sys, pathlib
path, old, new = sys.argv[1:4]
p = pathlib.Path(path)
text = p.read_text()
if old not in text:
    sys.exit(f"{path}: expected text not found: {old!r}")
p.write_text(text.replace(old, new))
PY
}

# replace_if_present FILE OLD NEW: for stopgaps upstream may fix on its own.
replace_if_present() {
  if grep -qF -- "$2" "$1"; then replace "$@"; else echo "note: $1 no longer has: $2"; fi
}

cd "$SRC"
test -f libs/hbb_common/src/config.rs || { echo "libs/hbb_common is missing (git submodule update --init)" >&2; exit 1; }

cfg=libs/hbb_common/src/config.rs
replace "$cfg" 'RwLock::new("RustDesk".to_owned())' "RwLock::new(\"$APP_NAME\".to_owned())"
replace "$cfg" '&["rs-ny.rustdesk.com"]' "&[\"$RENDEZVOUS\"]"
replace "$cfg" '"OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw="' "\"$PUBKEY\""

xc=flutter/macos/Runner/Configs/AppInfo.xcconfig
replace "$xc" 'PRODUCT_NAME = RustDesk' "PRODUCT_NAME = $APP_NAME"
replace "$xc" 'PRODUCT_BUNDLE_IDENTIFIER = com.carriez.flutterHbb' "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID"
replace flutter/macos/Runner.xcodeproj/project.pbxproj 'PRODUCT_BUNDLE_IDENTIFIER = com.carriez.rustdesk;' "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;"

# Upstream CI looks for the macOS bundle by its old name.
wf=.github/workflows/flutter-build.yml
replace "$wf" 'RustDesk.app' "$APP_NAME.app"
replace "$wf" 'Contents/MacOS/RustDesk ' "Contents/MacOS/$APP_NAME "
# GitHub retired the macos-14 arm64 runner; upstream 1.5.1 still asks for it.
replace_if_present "$wf" 'os: macos-14,' 'os: macos-15,'
# build.py copies the service binary into the bundle by its old name.
replace build.py 'Release/RustDesk.app' "Release/$APP_NAME.app"
replace build.py '--icon RustDesk.app 200 190 --hide-extension RustDesk.app' "--icon $APP_NAME.app 200 190 --hide-extension $APP_NAME.app"

for f in icon.png mac-icon.png icon.ico tray-icon.ico mac-tray-dark-x2.png mac-tray-light-x2.png; do
  cp "$ICONS/$f" "res/$f"
done
cp "$ICONS/32x32.png" res/32x32.png
cp "$ICONS/64x64.png" res/64x64.png
cp "$ICONS/128x128.png" res/128x128.png
cp "$ICONS/256x256.png" res/128x128@2x.png
cp "$ICONS/icon.svg" res/logo.svg
cp "$ICONS/icon.svg" res/scalable.svg
cp "$ICONS/icon.svg" flutter/assets/icon.svg
cp "$ICONS/icon.png" flutter/assets/icon.png
cp "$ICONS/AppIcon.icns" flutter/macos/Runner/AppIcon.icns
cp "$ICONS/app_icon.ico" flutter/windows/runner/resources/app_icon.ico

echo "SOLIS RD branding applied to $SRC as \"$APP_NAME\" ($BUNDLE_ID, $RENDEZVOUS)"
