# Example

A pub workspace with an app and two packages:

```yaml
# pubspec.yaml (workspace root)
name: my_workspace
publish_to: none

environment:
  sdk: ^3.13.0

workspace:
  - apps/mobile
  - packages/*

dev_dependencies:
  devimobile_devkit_cli: ^0.1.0

devkit:
  coverage:
    exclude:
      - '**/*.g.dart'
      - '**/*.freezed.dart'
    min: 80
```

```yaml
# packages/design_system/pubspec.yaml
devkit:
  coverage:
    min: 95
```

Run every package's tests with coverage, then merge and check thresholds:

```sh
dart pub get
dart run devimobile_devkit_cli:devkit test --coverage
dart run devimobile_devkit_cli:devkit coverage
```

Pass arguments to the test runner after `--`, for example to run only tests
whose name contains "login":

```sh
dart run devimobile_devkit_cli:devkit test -- --name login
```

In GitHub Actions:

```yaml
- uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0
  with:
    flutter-version-file: .fvmrc
- run: dart pub get
- run: dart run devimobile_devkit_cli:devkit test --coverage
- run: dart run devimobile_devkit_cli:devkit coverage
```
