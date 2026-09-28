#!/usr/bin/env bash
# Build the Moshi release tarball of react-native-enriched-markdown.
#
# Our commits only touch native code, so instead of the full upstream build
# (yarn, vendored grammars, RaTeX) this takes the published npm package of the
# upstream base version and overlays this branch's ios/ and android/ sources.
# If a commit ever changes src/, run the real `bob build` instead.
#
# Usage: moshi/pack.sh <base-version> <moshi-version>
#   moshi/pack.sh 1.0.2 1.0.2-moshi.1   → dist/react-native-enriched-markdown-1.0.2-moshi.1.tgz
set -euo pipefail
base=$1 version=$2
root=$(cd "$(dirname "$0")/.." && pwd)
pkg=$root/packages/react-native-enriched-markdown
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

(cd "$work" && npm pack "react-native-enriched-markdown@$base" -q --ignore-scripts >/dev/null && tar xzf ./*.tgz)
if ! git -C "$root" diff --quiet "v$base" -- "$pkg/src"; then
  echo "src/ differs from v$base: overlaying native code is not enough, build the JS" >&2
  exit 1
fi
for dir in ios android; do
  rsync -a --exclude generated --exclude build "$pkg/$dir/" "$work/package/$dir/"
done
(cd "$work/package" && npm pkg set version="$version" --ignore-scripts)
mkdir -p "$root/dist"
# npm pack would run the upstream prepare/prepack build; a package tarball is
# just package/ gzipped, so tar it directly.
out=$root/dist/react-native-enriched-markdown-$version.tgz
tar -czf "$out" -C "$work" package
echo "$out"
