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
| `avoid_edge_insets_literals` | `EdgeInsets.all(16)`, `EdgeInsets.only(left: 4)`, `EdgeInsetsDirectional.only(start: 8)`, `EdgeInsetsGeometry.all(16)`, `Padding(padding: .all(16))` | `EdgeInsets.zero`, `EdgeInsets.all(spacing)`, the `devicePixelRatio` of `EdgeInsets.fromViewPadding` |
| `avoid_sized_box_literals` | `SizedBox(height: 8)`, `SizedBox.square(dimension: 24)` | `SizedBox.shrink()`, `SizedBox.expand()`, `SizedBox()`, `SizedBox(width: double.infinity)` |
| `avoid_ui_string_literals` | `Text('Sign in')` and string literals passed to the Flutter parameters `tooltip`, `semanticsLabel`, `semanticLabel`, `hintText` and `labelText` | `Text(l10n.signIn)`, `Text('')`, `Text('$count')`, `Text('•')` |

Details:

- A numeric literal is a number written in code, also negated, in parentheses
  or in arithmetic of literals only (`-8`, `(4)`, `8 * 2`). `spacing * 2` is
  not a literal. A literal in a branch of `?:`, `??` or a `switch` expression
  counts (`isWide ? 24 : 16`). A constructor call is reported once, however
  many literals it has.
- The redirecting factories of `EdgeInsetsGeometry` are checked as the
  `EdgeInsets` or `EdgeInsetsDirectional` constructor they create.
- A string is reported when its literal text has a letter in any script;
  interpolated values are not literal text. Interpolations, adjacent strings,
  branches of `?:`, `??` and `switch` expressions (`name ?? 'Guest'`) and
  operands of `+` (`'Total: ' + total`) are checked.
- Only APIs declared in Flutter (`package:flutter` and `dart:ui`) are
  checked, so your own `Color`, `Text` or `hintText` are not reported. A
  `super.tooltip` parameter of your widget is followed to the Flutter
  parameter it forwards to.
- References in doc comments (`/// Defaults to [Colors.blue].`) are not
  reported.
- Only files in `lib/` are checked, and not in design system packages (see
  [Design system packages](#design-system-packages)). Tests, tools and examples may use
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

### Design system packages

The package that defines the design tokens has to use raw values, so the rules
skip the files of packages named `design_system`. Name your own design system
packages under the top-level `devimobile_devkit_rules:` key of
`analysis_options.yaml`, usually next to `plugins:` in the workspace root:

```yaml
plugins:
  devimobile_devkit_rules: ^0.1.0

devimobile_devkit_rules:
  design_system_packages:
    - brand_ui
```

- The list replaces the default, so add `design_system` if you still want it
  skipped; a single name works too (`design_system_packages: brand_ui`), and
  an empty list checks every package.
- For each file, the key is looked up in the nearest `analysis_options.yaml`
  (in the file's folder or above) and then in the files it includes,
  relative or `package:`. The including file wins, as in the analyzer, and a
  member whose file only has `include: ../../analysis_options.yaml` gets the
  root's list. Include cycles are cut.
- A missing or invalid value falls back to `design_system`. Invalid values
  are not reported.
- A package is matched by the `name` in its `pubspec.yaml`, so a dependency
  called `design_system` does not matter: files outside your workspace are
  not analyzed.

### Pub workspaces

Observed with Dart 3.13.7 (Flutter 3.47.9): `dart analyze` reports
`plugins` in a member's `analysis_options.yaml` as a warning ("Plugins can
only be specified in the root of a pub workspace…") and the plugin does not
run for that member. With `plugins:` in the root file, a member is checked
when it has no `analysis_options.yaml` of its own or when its file includes
the root file (`include: ../../analysis_options.yaml`); a member whose own
file does not include the root file is not checked. Keep the design system
in the include and list it in `design_system_packages`.

### `flutter analyze`

With Flutter 3.47, `flutter analyze` finishes before plugin diagnostics
arrive and does not show them. Use `dart analyze --fatal-infos` in CI.

## Versioning

The plugin depends on the `analyzer` version that its `analysis_server_plugin`
release requires, which moves with the Dart SDK, so the package stays below
1.0.0 for now. Before 1.0.0:

| Change | Version |
|---|---|
| A new rule, or a rule that reports more cases | minor (`0.x.0`) |
| Fewer false positives, fixes, documentation | patch (`0.x.y`) |

A patch upgrade therefore never adds diagnostics to code that passed before.

## License

MIT, see [LICENSE](LICENSE).
