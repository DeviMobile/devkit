/// Analyzer plugin that reports hard-coded colors, spacing and user-facing
/// text in Flutter apps.
///
/// The analysis server loads the plugin from `lib/main.dart`; enable it under
/// `plugins:` in `analysis_options.yaml` (see the package README). This
/// library exposes the plugin class and its rules for tools that compose
/// plugins.
library;

export 'package:devimobile_devkit_rules/src/plugin.dart' show DevkitRulesPlugin;
export 'package:devimobile_devkit_rules/src/rules/avoid_color_literals.dart';
export 'package:devimobile_devkit_rules/src/rules/avoid_edge_insets_literals.dart';
export 'package:devimobile_devkit_rules/src/rules/avoid_material_colors.dart';
export 'package:devimobile_devkit_rules/src/rules/avoid_sized_box_literals.dart';
export 'package:devimobile_devkit_rules/src/rules/avoid_ui_string_literals.dart';
