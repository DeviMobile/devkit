# devimobile_devkit_lints

Lint rule sets for Dart and Flutter. Every lint rule of the Dart SDK has a
recorded decision and a one-sentence reason in [RULES.md](RULES.md), and the
versioning policy below keeps a plain caret constraint safe to upgrade.

## Usage

```sh
dart pub add dev:devimobile_devkit_lints
```

`analysis_options.yaml`:

```yaml
include:
  - package:devimobile_devkit_lints/strict.yaml     # or core.yaml
  - package:devimobile_devkit_lints/formatter.yaml  # optional
```

Then apply the automatic fixes once:

```sh
dart fix --apply
```

## Rule sets

| File | For | Contents |
|---|---|---|
| `core.yaml` | packages and libraries | rules that prevent bugs; `strict-inference` |
| `strict.yaml` | apps | `core.yaml` plus style and consistency rules |
| `formatter.yaml` | anyone who wants it | formatter settings only (`trailing_commas: preserve`) |

Formatter settings live in their own file, so adopting the lints never changes
how your code is formatted unless you include `formatter.yaml` explicitly.
Don't include it in packages you publish: pub.dev scores formatting with the
default `dart format` settings.

The sets do not exclude generated files; add your own `analyzer: exclude:`
entries (for example `**/*.g.dart`) next to the `include`.

Experimental and deprecated SDK rules are never enabled.

## Versioning policy

| Change | Version |
|---|---|
| Enabling a rule, raising the minimum Dart SDK | major |
| Disabling a rule, adding a new file | minor |
| Documentation and reasons only | patch |

A minor or patch upgrade therefore never produces new diagnostics, so
`^x.y.z` is safe and there are no versioned include files. Before 1.0.0 the
same policy applies with the minor version in the role of major.

## How decisions are kept complete

- [`tool/decisions.yaml`](tool/decisions.yaml) is the source of truth;
  `core.yaml`, `strict.yaml` and `RULES.md` are generated from it by
  `dart run tool/generate.dart`.
- [`tool/sdk_rules.json`](tool/sdk_rules.json) is a snapshot of the Dart SDK's
  machine-readable lint catalog for one SDK version, refreshed by
  `dart run tool/update_sdk_rules.dart`.
- A test fails when the snapshot has a rule without a decision, a decision
  names an unknown or removed rule, two enabled rules are incompatible, an
  experimental rule is enabled, a generated file is stale, or the package's
  minimum SDK is lower than the newest enabled rule needs.

## License

MIT, see [LICENSE](LICENSE).
