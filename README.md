# devimobile devkit

Development tooling for Dart and Flutter projects, published on pub.dev.

| Package | What it does |
|---|---|
| [`devimobile_devkit_lints`](packages/devimobile_devkit_lints) | Lint rule sets with a documented decision for every SDK rule |

## Development

The repository is a [pub workspace](https://dart.dev/tools/pub/workspaces).
The Flutter version is pinned in `.fvmrc`.

```sh
dart pub get
dart format --set-exit-if-changed .
dart analyze --fatal-infos
(cd packages/devimobile_devkit_lints && dart run tool/generate.dart --check && dart test)
```

Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/);
pull requests are squash-merged.

See [PROVENANCE.md](PROVENANCE.md) for how code enters this repository and
[SECURITY.md](SECURITY.md) for reporting vulnerabilities.
