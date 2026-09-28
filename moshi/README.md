# Moshi fork

`moshi` branch: upstream release tag + Moshi's native fixes, one commit each.
Both Moshi apps (iOS and Android) install the release tarball by URL:

```json
"react-native-enriched-markdown": "https://github.com/rjyo/enriched-markdown/releases/download/v<version>/react-native-enriched-markdown-<version>.tgz"
```

## Release

```sh
moshi/pack.sh 1.0.2 1.0.2-moshi.N
gh release create v1.0.2-moshi.N dist/react-native-enriched-markdown-1.0.2-moshi.N.tgz --target moshi
```

## Resync with upstream

```sh
git fetch upstream --tags
git rebase --onto vX.Y.Z v1.0.2 moshi   # then pack with the new base version
```
