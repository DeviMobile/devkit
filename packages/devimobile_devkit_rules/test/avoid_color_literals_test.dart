import 'package:devimobile_devkit_rules/src/rules/avoid_color_literals.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final tester = RuleTester(AvoidColorLiterals.new);

  test('reports Color with a hex literal', () async {
    const code = '''
import 'package:flutter/material.dart';
Color brand() => Color(0xFF2196F3);
''';
    await tester.expectLints(code, ['Color(0xFF2196F3)']);
  });

  test('reports a const Color in a const widget', () async {
    const code = '''
import 'package:flutter/material.dart';
Widget box() => const ColoredBox(color: Color(0xFF000000));
''';
    await tester.expectLints(code, ['Color(0xFF000000)']);
  });

  test('reports Color.fromARGB once, not once per literal', () async {
    const code = '''
import 'package:flutter/material.dart';
final c = Color.fromARGB(255, 0, 0, 0);
''';
    await tester.expectLints(code, ['Color.fromARGB(255, 0, 0, 0)']);
  });

  test('reports Color.fromRGBO with a double literal', () async {
    const code = '''
import 'package:flutter/material.dart';
final c = Color.fromRGBO(10, 20, 30, 0.5);
''';
    await tester.expectLints(code, ['Color.fromRGBO(10, 20, 30, 0.5)']);
  });

  test('reports a dot shorthand and a prefixed dart:ui import', () async {
    const code = '''
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
final Color a = .new(0xFF000000);
final b = ui.Color(0xFFFFFFFF);
''';
    await tester.expectLints(code, [
      '.new(0xFF000000)',
      'ui.Color(0xFFFFFFFF)',
    ]);
  });

  test('ignores colors built from variables or computed values', () async {
    await tester.expectNone('''
import 'package:flutter/material.dart';
Color fromValue(int value) => Color(value);
Color shifted(int value) => Color(value + 1);
''');
  });

  test('ignores a class named Color from another library', () async {
    tester.addOtherPackageFile('lib/color.dart', '''
class Color {
  const Color(int value);
}
''');
    await tester.expectNone('''
import 'package:other_ui/color.dart';
const c = Color(0xFF000000);
''');
  });

  test('ignores files outside lib/', () async {
    await tester.expectNoneAt('test/widget_test.dart', '''
import 'package:flutter/material.dart';
const c = Color(0xFF000000);
''');
  });
}
