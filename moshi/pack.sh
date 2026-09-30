#!/usr/bin/env bash
# Build the Moshi release tarball of react-native-enriched-markdown.
#
# Our commits touch native code and, at most, the codegen specs
# (src/*NativeComponent.ts), so instead of the full upstream build (yarn,
# vendored grammars, RaTeX) this takes the published npm package of the
# upstream base version and overlays this branch's ios/ and android/ sources.
# Specs ship verbatim as .ts in both src/ and lib/module/ (the app's babel
# codegen plugin reads them), so they are overlaid too, and the package's
# checked-in codegen output (includesGeneratedCode) is regenerated from them
# with react-native from $RN_DIR (default: ../app-ios's). Any other src/
# change needs the real `bob build`.
#
# Usage: moshi/pack.sh <base-version> <moshi-version>
#   moshi/pack.sh 1.0.2 1.0.2-moshi.1   → dist/react-native-enriched-markdown-1.0.2-moshi.1.tgz
set -euo pipefail
base=$1 version=$2
root=$(cd "$(dirname "$0")/.." && pwd)
pkg=$root/packages/react-native-enriched-markdown
rn=${RN_DIR:-$root/../app-ios/node_modules/react-native}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

(cd "$work" && npm pack "react-native-enriched-markdown@$base" -q --ignore-scripts >/dev/null && tar xzf ./*.tgz)
changed=$(git -C "$root" diff --name-only "v$base" -- "$pkg/src")
if [[ -n $changed ]] && grep -qv 'NativeComponent\.ts$' <<<"$changed"; then
  echo "src/ differs from v$base beyond codegen specs: overlaying is not enough, build the JS" >&2
  exit 1
fi
for dir in ios android; do
  rsync -a --exclude generated --exclude build "$pkg/$dir/" "$work/package/$dir/"
done
if [[ -n $changed ]]; then
  for spec in $changed; do
    name=$(basename "$spec")
    cp "$root/$spec" "$work/package/src/$name"
    cp "$root/$spec" "$work/package/lib/module/$name"
  done
  codegen=$work/codegen
  for platform in ios android; do
    node "$rn/scripts/generate-codegen-artifacts.js" --path "$work/package" --outputPath "$codegen" \
      --targetPlatform "$platform" --source library >/dev/null
  done
  rm -rf "$work/package/ios/generated/ReactCodegen" "$work/package/android/generated/java" \
    "$work/package/android/generated/jni"
  mv "$codegen/ReactCodegen" "$work/package/ios/generated/ReactCodegen"
  mv "$codegen/java" "$codegen/jni" "$work/package/android/generated/"
fi
(cd "$work/package" && npm pkg set version="$version" --ignore-scripts)
mkdir -p "$root/dist"
# npm pack would run the upstream prepare/prepack build; a package tarball is
# just package/ gzipped, so tar it directly.
out=$root/dist/react-native-enriched-markdown-$version.tgz
tar -czf "$out" -C "$work" package
echo "$out"
