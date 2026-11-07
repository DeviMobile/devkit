import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:devimobile_devkit_rules/src/fixes/use_zero_insets.dart';
import 'package:devimobile_devkit_rules/src/rules/avoid_color_literals.dart';
import 'package:devimobile_devkit_rules/src/rules/avoid_edge_insets_literals.dart';
import 'package:devimobile_devkit_rules/src/rules/avoid_material_colors.dart';
import 'package:devimobile_devkit_rules/src/rules/avoid_sized_box_literals.dart';
import 'package:devimobile_devkit_rules/src/rules/avoid_ui_string_literals.dart';

/// Registers the rules and fixes of `devimobile_devkit_rules`.
///
/// Every rule is enabled by default once the plugin is listed under
/// `plugins:`; a single rule is turned off with `<rule>: false` under the
/// plugin's `diagnostics:` key.
class DevkitRulesPlugin extends Plugin {
  @override
  String get name => 'devimobile_devkit_rules';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(AvoidColorLiterals())
      ..registerWarningRule(AvoidMaterialColors())
      ..registerWarningRule(AvoidEdgeInsetsLiterals())
      ..registerWarningRule(AvoidSizedBoxLiterals())
      ..registerWarningRule(AvoidUiStringLiterals())
      ..registerFixForRule(AvoidEdgeInsetsLiterals.code, UseZeroInsets.new);
  }
}
