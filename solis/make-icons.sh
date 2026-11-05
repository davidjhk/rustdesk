#!/bin/bash
# Renders the SOLIS RD icon set from solis-rd-icon.svg into ./icons.
# macOS only (Quick Look renders the SVG gradients; ImageMagick's own SVG
# reader drops them). Run again only when the SVG changes; the output is
# committed so the build machine never needs to render anything.
set -euo pipefail
cd "$(dirname "$0")"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
out=icons; mkdir -p "$out"

qlmanage -t -s 1024 -o "$work" solis-rd-icon.svg >/dev/null 2>&1
# Quick Look paints an opaque white square; cut it back to the round mark.
magick "$work/solis-rd-icon.svg.png" \
  \( -size 1024x1024 xc:black -fill white -draw "circle 512,512 512,42" \) \
  -alpha off -compose CopyOpacity -composite "$out/icon.png"

# macOS app icon: the mark sits inside Apple's 824px icon grid.
magick "$out/icon.png" -resize 824x824 -background none -gravity center -extent 1024x1024 "$out/mac-icon.png"
for s in 32 64 128 256; do magick "$out/icon.png" -resize ${s}x${s} "$out/${s}x${s}.png"; done
magick "$out/icon.png" -define icon:auto-resize=128,64,48,32,16 "$out/icon.ico"
magick "$out/icon.png" -define icon:auto-resize=256,128,64,48,32,16 "$out/app_icon.ico"
magick "$out/icon.png" -resize 32x32 "$out/tray-icon.ico"

# macOS menu-bar template: black rings on transparent; macOS recolours it.
magick "$out/icon.png" -alpha extract "$work/a.png"
magick "$out/icon.png" -colorspace gray -negate -threshold 30% "$work/rings.png"
magick "$work/rings.png" -alpha copy -fill black -colorize 100 "$work/tmpl.png"
magick "$work/tmpl.png" -resize 60x60 "$out/mac-tray-dark-x2.png"
magick "$work/tmpl.png" -resize 48x48 "$out/mac-tray-light-x2.png"

iconset="$work/AppIcon.iconset"; mkdir -p "$iconset"
for s in 16 32 128 256 512; do
  magick "$out/mac-icon.png" -resize ${s}x${s} "$iconset/icon_${s}x${s}.png"
  magick "$out/mac-icon.png" -resize $((s*2))x$((s*2)) "$iconset/icon_${s}x${s}@2x.png"
done
iconutil -c icns "$iconset" -o "$out/AppIcon.icns"
cp solis-rd-icon.svg "$out/icon.svg"
ls -1 "$out"
