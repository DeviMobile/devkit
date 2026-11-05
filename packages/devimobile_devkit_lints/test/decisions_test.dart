import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../tool/src/catalog.dart';

void main() {
  final catalog = SdkCatalog.parse(
    File('tool/sdk_rules.json').readAsStringSync(),
  );
  final decisions = parseDecisions(
    File('tool/decisions.yaml').readAsStringSync(),
  );

  SdkRule rule(
    String name, {
    String state = 'stable',
    List<String> incompatible = const [],
  }) => SdkRule(
    name: name,
    state: state,
    sinceDartSdk: '3.0',
    fixStatus: 'noFix',
    incompatible: incompatible,
    description: '',
  );

  Decision decide(String name, Level level) =>
      Decision(name: name, level: level, reason: 'reason');

  SdkCatalog catalogOf(List<SdkRule> rules) =>
      SdkCatalog(sdk: '9.9.9', source: 'test', rules: rules);

  group('decisions.yaml', () {
    test('has a valid decision for every rule of the SDK snapshot', () {
      expect(validate(catalog, decisions), isEmpty);
    });

    test('generated files are up to date', () {
      final outputs = renderOutputs(catalog, decisions);
      for (final MapEntry(key: path, value: content) in outputs.entries) {
        expect(
          File(path).readAsStringSync(),
          content,
          reason: '$path is stale; run `dart run tool/generate.dart`',
        );
      }
    });

    test('pubspec SDK lower bound covers every enabled rule', () {
      final pubspec =
          loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
      final environment = pubspec['environment'] as YamlMap;
      final constraint = environment['sdk'] as String;
      final lowerBound = RegExp(
        r'(\d+\.\d+\.\d+)',
      ).firstMatch(constraint)!.group(1)!;
      expect(
        compareVersions(lowerBound, minimumSdk(catalog, decisions)),
        greaterThanOrEqualTo(0),
      );
    });
  });

  group('validate', () {
    test('reports an SDK rule without a decision', () {
      final problems = validate(
        catalogOf([rule('known'), rule('brand_new_rule')]),
        {'known': decide('known', Level.core)},
      );
      expect(problems, [contains('brand_new_rule: no decision')]);
    });

    test('ignores removed rules without a decision', () {
      final problems = validate(
        catalogOf([rule('gone', state: 'removed')]),
        const {},
      );
      expect(problems, isEmpty);
    });

    test('reports decisions for unknown and removed rules', () {
      final problems = validate(
        catalogOf([rule('gone', state: 'removed')]),
        {
          'gone': decide('gone', Level.off),
          'typo': decide('typo', Level.off),
        },
      );
      expect(problems, [
        contains('gone: removed from the SDK'),
        contains('typo: not in the SDK'),
      ]);
    });

    test('reports enabled experimental rules', () {
      final problems = validate(
        catalogOf([rule('new_idea', state: 'experimental')]),
        {'new_idea': decide('new_idea', Level.strict)},
      );
      expect(problems, [contains('experimental rules must stay off')]);
    });

    test('reports incompatible rules enabled across core and strict', () {
      final problems = validate(
        catalogOf([
          rule('single', incompatible: ['double']),
          rule('double', incompatible: ['single']),
        ]),
        {
          'single': decide('single', Level.core),
          'double': decide('double', Level.strict),
        },
      );
      expect(problems, ['double and single are incompatible but both enabled']);
    });
  });

  test('compareVersions orders numerically', () {
    expect(compareVersions('3.13', '3.9'), greaterThan(0));
    expect(compareVersions('3.13.0', '3.13'), 0);
    expect(compareVersions('2.19', '3.0'), lessThan(0));
  });
}
