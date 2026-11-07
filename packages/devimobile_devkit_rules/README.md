# devimobile_devkit_rules

An analyzer plugin for Flutter apps that reports hard-coded colors, spacing
and user-facing text, so that design tokens and localizations stay the only
source of these values. It runs inside the Dart analysis server
(`analysis_server_plugin`), so it works in the IDE and in `dart analyze`
without a separate process.

## Usage

Enable the plugin in the `analysis_options.yaml` at the root of your package,
or at the root of your [pub workspace](https://dart.dev/tools/pub/workspaces):

```yaml
plugins:
  devimobile_devkit_rules: ^0.1.0
```

The analysis server resolves the plugin on its own; it does not need to be in
your `pubspec.yaml`. Restart the analysis server after changing `plugins:`.

```sh
dart analyze --fatal-infos
```

Every rule is enabled once the plugin is listed and reports a warning.

## Rules

| Rule | Reports | Allowed |
|---|---|---|
| `avoid_color_literals` | `Color(0xFF2196F3)`, `Color.fromARGB(255, 0, 0, 0)`, any `dart:ui` `Color` constructor with a numeric literal | `Color(value)` from a variable |
| `avoid_material_colors` | `Colors.blue`, `Colors.red.shade100` | `Colors.transparent` |
| `avoid_edge_insets_literals` | `EdgeInsets.all(16)`, `EdgeInsets.only(left: 4)`, `EdgeInsetsDirectional.only(start: 8)`, `.symmetric(vertical: 8)` | `EdgeInsets.zero`, `EdgeInsets.all(spacing)` |
| `avoid_sized_box_literals` | `SizedBox(height: 8)`, `SizedBox.square(dimension: 24)` | `SizedBox.shrink()`, `SizedBox.expand()`, `SizedBox()`, `SizedBox(width: double.infinity)` |
| `avoid_ui_string_literals` | `Text('Sign in')` and string literals passed to the Flutter parameters `tooltip`, `semanticsLabel`, `semanticLabel`, `hintText` and `labelText` | `Text(l10n.signIn)`, `Text('')`, `Text('$count')`, `Text('•')` |

Details:

- A numeric literal is a number written in code, also negated, in parentheses
  or in arithmetic of literals only (`-8`, `(4)`, `8 * 2`). `spacing * 2` is
  not a literal. A constructor call is reported once, however many literals
  it has.
- A string is reported when its literal text has a letter in any script;
  interpolated values are not literal text. Interpolations, adjacent strings
  and both branches of a conditional (`ok ? 'Yes' : 'No'`) are checked.
- Only APIs declared in Flutter (`package:flutter` and `dart:ui`) are
  checked, so your own `Color`, `Text` or `hintText` are not reported. A
  `super.tooltip` parameter of your widget is followed to the Flutter
  parameter it forwards to.
- Only files in `lib/` are checked. Tests, tools and examples may use
  literals.
- Generated files are checked like any other file in `lib/`; exclude them
  with `analyzer: exclude:` as usual.

## Fixes

`avoid_edge_insets_literals` offers a quick fix in the IDE when every literal
is zero: `EdgeInsets.all(0)` becomes `EdgeInsets.zero` (also
`EdgeInsetsDirectional.zero` and `.zero` for a dot shorthand). `dart fix`
does not apply fixes from analyzer plugins.

## Configuration

Turn off a rule or change its severity under the plugin's `diagnostics:` key:

```yaml
plugins:
  devimobile_devkit_rules:
    version: ^0.1.0
    diagnostics:
      avoid_ui_string_literals: false
      avoid_sized_box_literals: info
```

Suppress a single diagnostic with the plugin name in front of the rule:

```dart
// ignore: devimobile_devkit_rules/avoid_material_colors
```

### Pub workspaces

Plugins can only be listed in the `analysis_options.yaml` at the root of a
workspace. A member package gets the plugin when its own
`analysis_options.yaml` includes the root file (or when it has none). A
package that keeps its own options without that include, such as a design
system that defines the colors and spacing, is not checked.

### `flutter analyze`

With Flutter 3.47, `flutter analyze` finishes before plugin diagnostics
arrive and does not show them. Use `dart analyze --fatal-infos` in CI.

## Versioning

The plugin depends on the exact `analyzer` version that its
`analysis_server_plugin` release requires, which moves with the Dart SDK, so
the package stays below 1.0.0 for now. A release that enables a new rule or
reports more cases is a minor release (`0.x.0`); fixes that report fewer false
positives are patch releases.

## License

MIT, see [LICENSE](LICENSE).
