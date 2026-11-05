# Example

`pubspec.yaml`:

```yaml
dev_dependencies:
  devimobile_devkit_lints: ^0.1.0
```

`analysis_options.yaml` of an app:

```yaml
include:
  - package:devimobile_devkit_lints/strict.yaml
  - package:devimobile_devkit_lints/formatter.yaml

analyzer:
  exclude:
    - '**/*.g.dart'
    - '**/*.freezed.dart'
```

`analysis_options.yaml` of a published package:

```yaml
include: package:devimobile_devkit_lints/core.yaml

linter:
  rules:
    - public_member_api_docs
```

Turning off a rule for one project, with the reason next to it:

```yaml
include: package:devimobile_devkit_lints/strict.yaml

linter:
  rules:
    # Generated SDK bindings use positional flags we cannot rename.
    avoid_positional_boolean_parameters: false
```
