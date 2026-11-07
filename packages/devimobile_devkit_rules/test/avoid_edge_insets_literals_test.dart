import 'package:devimobile_devkit_rules/src/rules/avoid_edge_insets_literals.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final tester = RuleTester(AvoidEdgeInsetsLiterals.new);

  test('reports each EdgeInsets constructor with a literal', () async {
    const code = '''
import 'package:flutter/material.dart';
final a = EdgeInsets.all(16);
final b = EdgeInsets.symmetric(horizontal: 8.0);
final c = EdgeInsets.only(left: 4);
final d = EdgeInsets.fromLTRB(1, 2, 3, 4);
''';
    await tester.expectLints(code, [
      'EdgeInsets.all(16)',
      'EdgeInsets.symmetric(horizontal: 8.0)',
      'EdgeInsets.only(left: 4)',
      'EdgeInsets.fromLTRB(1, 2, 3, 4)',
    ]);
  });

  test('reports const insets, negative and computed literals', () async {
    const code = '''
import 'package:flutter/material.dart';
Widget pad(Widget child) =>
    Padding(padding: const EdgeInsets.all(-8), child: child);
final b = EdgeInsets.all((8 * 2));
''';
    await tester.expectLints(code, [
      'const EdgeInsets.all(-8)',
      'EdgeInsets.all((8 * 2))',
    ]);
  });

  test('reports EdgeInsetsDirectional and dot shorthands', () async {
    const code = '''
import 'package:flutter/material.dart';
final a = EdgeInsetsDirectional.only(start: 8);
final EdgeInsets b = .all(8);
''';
    await tester.expectLints(code, [
      'EdgeInsetsDirectional.only(start: 8)',
      '.all(8)',
    ]);
  });

  test('reports a literal next to a token once', () async {
    const code = '''
import 'package:flutter/material.dart';
EdgeInsets mixed(double spacing) => EdgeInsets.only(left: spacing, top: 4);
''';
    await tester.expectLints(code, ['EdgeInsets.only(left: spacing, top: 4)']);
  });

  test('allows EdgeInsets.zero and values from tokens', () async {
    await tester.expectNone('''
import 'package:flutter/material.dart';
const a = EdgeInsets.zero;
const EdgeInsets b = .zero;
EdgeInsets c(double spacing) => EdgeInsets.all(spacing);
EdgeInsets d(double spacing) => EdgeInsets.symmetric(vertical: spacing * 2);
''');
  });

  test('ignores a class named EdgeInsets outside Flutter', () async {
    tester.addOtherPackageFile('lib/insets.dart', '''
class EdgeInsets {
  const EdgeInsets.all(double value);
}
''');
    await tester.expectNone('''
import 'package:other_ui/insets.dart';
const a = EdgeInsets.all(16);
''');
  });

  test('ignores files outside lib/', () async {
    await tester.expectNoneAt('test/widget_test.dart', '''
import 'package:flutter/material.dart';
const a = EdgeInsets.all(16);
''');
  });
}
