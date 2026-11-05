# devimobile_devkit_cli

The `devkit` command runs the tests of every package in a Dart or Flutter
[pub workspace](https://dart.dev/tools/pub/workspaces) and merges their
coverage into one lcov report with excludes and thresholds.

```sh
dart pub add dev:devimobile_devkit_cli
dart run devimobile_devkit_cli:devkit test --coverage
dart run devimobile_devkit_cli:devkit coverage
```

or globally: `dart pub global activate devimobile_devkit_cli`, then `devkit …`.

devkit makes no network requests and collects no telemetry.

## `devkit test`

Finds the packages (the members listed under `workspace:` in the root
`pubspec.yaml`, globs included, or the current package when there is no
workspace) and runs `flutter test` in packages that depend on Flutter and
`dart test` in the others. Packages without a `test/` directory are listed as
"no tests".

```text
Package       Path                   Runner   Passed  Failed  Skipped  Time  Result
------------  ---------------------  -------  ------  ------  -------  ----  ------
dart_failing  packages/dart_failing  dart          1       1        0  2.7s  FAILED
dart_ok       packages/dart_ok       dart          2       0        1  1.1s  ok
flutter_ok    packages/flutter_ok    flutter       1       0        0  4.1s  ok
no_tests      packages/no_tests                                              no tests

Failed in dart_failing:
  - answers 42

1 of 3 tested packages failed: dart_failing
```

- Results come from the test runner's JSON report file, read after the
  process ends, never from parsing console output.
- A package passes only with exit code 0 **and** a complete report without
  failures; a suite that fails to load counts as a failure.
- The exit code is 1 when any package fails.

| Option | |
|---|---|
| `--coverage` | write `<package>/coverage/lcov.info` |
| `-j, --jobs <n>` | packages tested at the same time (default 1) |
| `--no-fvm-check` | skip the `.fvmrc` check |
| `-- <args>` | passed to every `dart test` / `flutter test` |

**FVM**: when the workspace root has an `.fvmrc` pinning a Flutter version,
devkit compares it with `flutter` on `PATH` and stops with a hint if they
differ (`fvm exec devkit test` runs it with the pinned version).

## `devkit coverage`

Merges `coverage/lcov.info` of every tested package into
`coverage/lcov.info` at the workspace root, with paths relative to the root,
and checks thresholds. Run `devkit test --coverage` first.

Configuration lives under `devkit:` in `pubspec.yaml`:

```yaml
# root pubspec.yaml
devkit:
  coverage:
    exclude:            # globs relative to the workspace root
      - '**/*.g.dart'
      - '**/*.freezed.dart'
    min: 80             # line coverage in percent: total and every package
```

```yaml
# packages/foo/pubspec.yaml
devkit:
  coverage:
    exclude:            # globs relative to this package, added to the root's
      - 'lib/l10n/**'
    min: 60             # replaces the root minimum for this package
```

Unknown keys are errors, so a typo cannot silently disable a threshold.

| Option | |
|---|---|
| `-o, --output <path>` | merged report, relative to the root (default `coverage/lcov.info`) |
| `--min <percent>` | replaces the root `min` |

Coverage is line coverage. Files that no test loads do not appear in the
runners' lcov output, so they do not count against the total.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | failed tests or coverage below minimum |
| 2 | configuration or environment problem (e.g. `.fvmrc` mismatch) |
| 64 | invalid command line |

## License

MIT, see [LICENSE](LICENSE).
