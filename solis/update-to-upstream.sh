#!/bin/bash
# Replaces this tree with RustDesk <tag> plus the SOLIS-RD branding.
#
#   solis/update-to-upstream.sh <upstream-tag>
#
# Run from the repo root on the solis-rd branch; it leaves the result
# uncommitted. Submodules are vendored in, so the build needs only this repo.
set -euo pipefail
TAG="${1:?usage: $0 <upstream-tag>}"
ROOT="$(git rev-parse --show-toplevel)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

git -c advice.detachedHead=false clone -q --depth 1 --branch "$TAG" --recurse-submodules --shallow-submodules \
  https://github.com/rustdesk/rustdesk.git "$WORK/src"

# Our own pieces travel with every update.
cp -R "$ROOT/solis" "$WORK/src/solis"
cp "$ROOT"/.github/workflows/solis-rd-*.yml "$WORK/src/.github/workflows/"

"$ROOT/solis/apply-solis-rd.sh" "$WORK/src"

find "$WORK/src" -name .git -prune -exec rm -rf {} +
rm -f "$WORK/src/.gitmodules"
echo "$TAG" > "$WORK/src/solis/UPSTREAM_VERSION"

rsync -a --delete --exclude /.git "$WORK/src/" "$ROOT/"
echo "tree now RustDesk $TAG + SOLIS-RD branding"
