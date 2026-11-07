import 'package:devimobile_devkit_rules/src/rules/avoid_sized_box_literals.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final tester = RuleTester(AvoidSizedBoxLiterals.new);

  test('reports SizedBox sized by literals, once per box', () async {
    const code = '''
import 'package:flutter/material.dart';
const a = SizedBox(height: 8);
final b = SizedBox(width: 16.0, height: 8);
const c = SizedBox.square(dimension: 24);
''';
    await tester.expectLints(code, [
      'SizedBox(height: 8)',
      'SizedBox(width: 16.0, height: 8)',
      'SizedBox.square(dimension: 24)',
    ]);
  });

  test('reports a SizedBox nested in a const widget tree', () async {
    const code = '''
import 'package:flutter/material.dart';
Widget gap() => const Column(children: [SizedBox(height: 12)]);
''';
    await tester.expectLints(code, ['SizedBox(height: 12)']);
  });

  test('reports a literal in a conditional size once', () async {
    const code = '''
import 'package:flutter/material.dart';
SizedBox gap(bool isWide) => SizedBox(height: isWide ? 24 : 16);
''';
    await tester.expectLints(code, ['SizedBox(height: isWide ? 24 : 16)']);
  });

  test('allows shrink, expand, no size, infinity and tokens', () async {
    await tester.expectNone('''
import 'package:flutter/material.dart';
const a = SizedBox.shrink();
const b = SizedBox.expand();
const c = SizedBox();
const d = SizedBox(width: double.infinity);
SizedBox e(double spacing) => SizedBox(height: spacing);
''');
  });

  test('ignores files outside lib/', () async {
    await tester.expectNoneAt('test/widget_test.dart', '''
import 'package:flutter/material.dart';
const a = SizedBox(height: 8);
''');
  });
}
