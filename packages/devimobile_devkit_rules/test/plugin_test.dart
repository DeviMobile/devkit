import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/error/error.dart';
import 'package:devimobile_devkit_rules/main.dart';
import 'package:devimobile_devkit_rules/src/rules/avoid_edge_insets_literals.dart';
import 'package:test/test.dart';

void main() {
  final registry = _RecordingRegistry();
  plugin.register(registry);

  test('names the plugin after the package', () {
    expect(plugin.name, 'devimobile_devkit_rules');
  });

  test('enables every rule by default as a warning', () {
    expect(registry.lintRules, isEmpty);
    expect(registry.warningRules.map((rule) => rule.name), [
      'avoid_color_literals',
      'avoid_material_colors',
      'avoid_edge_insets_literals',
      'avoid_sized_box_literals',
      'avoid_ui_string_literals',
    ]);
    for (final rule in registry.warningRules) {
      final codes = rule.diagnosticCodes;
      expect(codes.map((code) => code.lowerCaseName), [rule.name]);
      expect(codes.single.severity, DiagnosticSeverity.WARNING);
      expect(rule.description, isNotEmpty);
    }
  });

  test('registers the zero-insets fix for the insets rule', () {
    expect(registry.fixes.keys, [AvoidEdgeInsetsLiterals.code]);
  });
}

/// Records what the plugin registers; the analysis server is not involved.
class _RecordingRegistry implements PluginRegistry {
  final lintRules = <AbstractAnalysisRule>[];
  final warningRules = <AbstractAnalysisRule>[];
  final fixes = <DiagnosticCode, Object>{};

  @override
  Iterable<AbstractAnalysisRule> enabled(Map<String, Object?> ruleConfigs) =>
      throw UnimplementedError();

  @override
  void registerAssist(Object generator) => throw UnimplementedError();

  @override
  void registerFixForRule(DiagnosticCode code, Object generator) =>
      fixes[code] = generator;

  @override
  void registerLintRule(AbstractAnalysisRule rule) => lintRules.add(rule);

  @override
  void registerWarningRule(AbstractAnalysisRule rule) => warningRules.add(rule);
}
