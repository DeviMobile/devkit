import 'package:devimobile_devkit_rules/src/fixes/use_zero_insets.dart';
import 'package:devimobile_devkit_rules/src/rules/avoid_edge_insets_literals.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final tester = RuleTester(AvoidEdgeInsetsLiterals.new);

  Future<String?> fix(String body) => tester.applyFix(
    "import 'package:flutter/material.dart' as m;\n"
    "import 'package:flutter/material.dart';\n"
    '$body\n',
    (context) => UseZeroInsets(context: context),
  );

  test('replaces all-zero insets with the zero constant', () async {
    expect(
      await fix('final a = EdgeInsets.all(0);'),
      endsWith('''
final a = EdgeInsets.zero;
'''),
    );
  });

  test('drops const and keeps the import prefix', () async {
    expect(
      await fix(
        'const a = m.EdgeInsets.symmetric(vertical: 0, horizontal: -0.0);',
      ),
      endsWith('const a = m.EdgeInsets.zero;\n'),
    );
    expect(
      await fix('final a = const EdgeInsets.fromLTRB(0, (0), 0, 0);'),
      endsWith('final a = EdgeInsets.zero;\n'),
    );
  });

  test('keeps the class of directional insets', () async {
    expect(
      await fix('const a = EdgeInsetsDirectional.only(start: 0);'),
      endsWith('const a = EdgeInsetsDirectional.zero;\n'),
    );
  });

  test('evaluates arithmetic of literals', () async {
    expect(
      await fix('final a = EdgeInsets.all(0 * 8);'),
      endsWith('final a = EdgeInsets.zero;\n'),
    );
    expect(await fix('final a = EdgeInsets.all(8 ~/ 0);'), isNull);
  });

  test('handles EdgeInsetsGeometry factories and shorthands', () async {
    expect(
      await fix('const a = EdgeInsetsGeometry.all(0);'),
      endsWith('const a = EdgeInsetsGeometry.zero;\n'),
    );
    expect(
      await fix('const a = Padding(padding: .all(0));'),
      endsWith('const a = Padding(padding: .zero);\n'),
    );
  });

  test('replaces a dot shorthand with .zero', () async {
    expect(
      await fix('const EdgeInsets a = .only(left: 0);'),
      endsWith('const EdgeInsets a = .zero;\n'),
    );
  });

  test('offers nothing when a value is not zero', () async {
    expect(await fix('final a = EdgeInsets.all(8);'), isNull);
    expect(
      await fix('EdgeInsets f(double s) => EdgeInsets.only(left: 0, top: s);'),
      isNull,
    );
  });

  test('describes the replacement', () async {
    await tester.applyFix("import 'package:flutter/material.dart';\n"
        'final a = EdgeInsets.all(0);\n', (context) {
      final producer = UseZeroInsets(context: context);
      expect(producer.fixKind.id, contains('useZeroInsets'));
      expect(producer.multiFixKind.id, contains('useZeroInsets'));
      return producer;
    });
  });
}
