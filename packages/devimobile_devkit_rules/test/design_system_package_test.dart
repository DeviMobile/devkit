import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:devimobile_devkit_rules/devimobile_devkit_rules.dart';
import 'package:devimobile_devkit_rules/src/scope.dart';
import 'package:test/test.dart';

import 'support.dart';

/// One violation of every rule.
const _code = '''
import 'package:flutter/material.dart';
const a = Color(0xFF000000);
const b = Colors.red;
const c = EdgeInsets.all(16);
const d = SizedBox(height: 8);
const e = Text('Hello');
''';

final _rules = <String, (AbstractAnalysisRule Function(), String)>{
  'avoid_color_literals': (AvoidColorLiterals.new, 'Color(0xFF000000)'),
  'avoid_material_colors': (AvoidMaterialColors.new, 'Colors.red'),
  'avoid_edge_insets_literals': (
    AvoidEdgeInsetsLiterals.new,
    'EdgeInsets.all(16)',
  ),
  'avoid_sized_box_literals': (
    AvoidSizedBoxLiterals.new,
    'SizedBox(height: 8)',
  ),
  'avoid_ui_string_literals': (AvoidUiStringLiterals.new, "'Hello'"),
};

void main() {
  for (final MapEntry(key: name, value: (create, snippet)) in _rules.entries) {
    group('$name in the default design_system package', () {
      final tester = RuleTester(create, packageName: 'design_system');

      test('reports nothing', () async {
        await tester.expectNone(_code);
      });

      test('reports again when the list is empty', () async {
        tester.setAnalysisOptions('''
devimobile_devkit_rules:
  design_system_packages: []
''');
        await tester.expectLints(_code, [snippet]);
      });
    });

    group('$name in a custom design system package', () {
      final tester = RuleTester(create, packageName: 'brand_ui');

      test('reports without configuration', () async {
        await tester.expectLints(_code, [snippet]);
      });

      test('reports nothing when the package is listed', () async {
        tester.setAnalysisOptions('''
devimobile_devkit_rules:
  design_system_packages:
    - tokens
    - brand_ui
''');
        await tester.expectNone(_code);
      });
    });
  }

  group('configured names replace the default', () {
    final tester = RuleTester(
      AvoidColorLiterals.new,
      packageName: 'design_system',
    );

    test('so design_system is checked when not listed', () async {
      tester.setAnalysisOptions('''
devimobile_devkit_rules:
  design_system_packages: brand_ui
''');
      await tester.expectLints(_code, ['Color(0xFF000000)']);
    });
  });

  group('an app package', () {
    final tester = RuleTester(AvoidColorLiterals.new, packageName: 'mobile');

    test('is checked next to a listed design system', () async {
      tester.setAnalysisOptions('''
devimobile_devkit_rules:
  design_system_packages: [design_system]
''');
      await tester.expectLints(_code, ['Color(0xFF000000)']);
    });
  });

  group('a package whose options file includes the root file', () {
    final tester = RuleTester(AvoidColorLiterals.new, packageName: 'brand_ui');

    test('reads the key from the included file', () async {
      tester
        ..writeWorkspaceFile('analysis_options.yaml', '''
devimobile_devkit_rules:
  design_system_packages: [brand_ui]
''')
        ..setAnalysisOptions('include: ../analysis_options.yaml');
      await tester.expectNone(_code);
    });

    test('follows a chain of includes and a list of includes', () async {
      tester
        ..writeWorkspaceFile('shared/base.yaml', '''
devimobile_devkit_rules:
  design_system_packages: brand_ui
''')
        ..writeWorkspaceFile('shared/app.yaml', 'include: base.yaml\n')
        ..writeWorkspaceFile('shared/empty.yaml', 'linter:\n')
        ..setAnalysisOptions('''
include:
  - ../shared/app.yaml
  - ../shared/empty.yaml
''');
      await tester.expectNone(_code);
    });

    test('reads a package: include', () async {
      tester
        ..writeOtherPackageFile('lib/rules.yaml', '''
devimobile_devkit_rules:
  design_system_packages: [brand_ui]
''')
        ..setAnalysisOptions('include: package:other_ui/rules.yaml');
      await tester.expectNone(_code);
    });

    test('prefers the key of the including file', () async {
      tester
        ..writeWorkspaceFile('analysis_options.yaml', '''
devimobile_devkit_rules:
  design_system_packages: [brand_ui]
''')
        ..setAnalysisOptions('''
include: ../analysis_options.yaml
devimobile_devkit_rules:
  design_system_packages: [tokens]
''');
      await tester.expectLints(_code, ['Color(0xFF000000)']);
    });

    test('stops at an include cycle and uses the default', () async {
      tester
        ..writeWorkspaceFile('a.yaml', 'include: b.yaml\n')
        ..writeWorkspaceFile('b.yaml', 'include: a.yaml\n')
        ..setAnalysisOptions('include: ../a.yaml');
      await tester.expectLints(_code, ['Color(0xFF000000)']);
    });
  });

  group('a changed options file', () {
    final tester = RuleTester(AvoidColorLiterals.new, packageName: 'brand_ui');

    test('is read again', () async {
      tester.setAnalysisOptions('''
devimobile_devkit_rules:
  design_system_packages: [brand_ui]
''');
      await tester.expectNone(_code);
      tester.rewriteAnalysisOptions('''
devimobile_devkit_rules:
  design_system_packages: []
''');
      await tester.expectLints(_code, ['Color(0xFF000000)']);
    });
  });

  group('parseDesignSystemPackages', () {
    test('defaults to design_system', () {
      expect(parseDesignSystemPackages(''), {'design_system'});
      expect(parseDesignSystemPackages('include: package:x/y.yaml\n'), {
        'design_system',
      });
      expect(
        parseDesignSystemPackages('devimobile_devkit_rules:\n  other: 1\n'),
        {'design_system'},
      );
    });

    test('reads a name or a list of names', () {
      expect(
        parseDesignSystemPackages(
          'devimobile_devkit_rules:\n  design_system_packages: ui\n',
        ),
        {'ui'},
      );
      expect(
        parseDesignSystemPackages(
          'devimobile_devkit_rules:\n  design_system_packages: [a, b]\n',
        ),
        {'a', 'b'},
      );
      expect(
        parseDesignSystemPackages(
          'devimobile_devkit_rules:\n  design_system_packages: []\n',
        ),
        isEmpty,
      );
    });

    test('falls back to the default for invalid values', () {
      for (final yaml in [
        'devimobile_devkit_rules:\n  design_system_packages: 3\n',
        'devimobile_devkit_rules:\n  design_system_packages: [a, 3]\n',
        'devimobile_devkit_rules: [a]\n',
        '- not a map\n',
        'key: [unclosed\n',
      ]) {
        expect(parseDesignSystemPackages(yaml), {
          'design_system',
        }, reason: yaml);
      }
    });
  });
}
