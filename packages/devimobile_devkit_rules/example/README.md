# Example

`analysis_options.yaml` of an app (or of the workspace root):

```yaml
include: package:devimobile_devkit_lints/strict.yaml

plugins:
  devimobile_devkit_rules: ^0.1.0
```

`lib/home_page.dart`:

```dart
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16), // avoid_edge_insets_literals
      child: ColoredBox(
        color: Color(0xFF2196F3), // avoid_color_literals
        child: Text('Welcome'), // avoid_ui_string_literals
      ),
    );
  }
}
```

`dart analyze --fatal-infos`:

```text
warning - lib/home_page.dart:9:16 - Insets built from a numeric literal. Try using spacing from the design system, or EdgeInsets.zero. - avoid_edge_insets_literals
warning - lib/home_page.dart:11:16 - Color built from a numeric literal. Try using a color from the design system. - avoid_color_literals
warning - lib/home_page.dart:12:21 - User-facing text in a string literal ('Text'). Try using a localized string. - avoid_ui_string_literals
```

The same widget written with design tokens and localizations passes:

```dart
Padding(
  padding: EdgeInsets.all(context.spacing.md),
  child: ColoredBox(
    color: context.colors.primary,
    child: Text(context.l10n.welcome),
  ),
);
```
