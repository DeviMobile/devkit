import 'package:devimobile_devkit_rules/src/rules/avoid_material_colors.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final tester = RuleTester(AvoidMaterialColors.new);

  test('reports a Material palette color with its name', () async {
    const code = '''
import 'package:flutter/material.dart';
Widget box() => const ColoredBox(color: Colors.red);
''';
    await tester.expectLints(
      code,
      ['Colors.red'],
      messageContainsAll: ['Colors.red'],
    );
  });

  test('reports the palette color once when a shade is used', () async {
    const code = '''
import 'package:flutter/material.dart';
final c = Colors.red.shade100;
''';
    await tester.expectLints(code, ['Colors.red']);
  });

  test('reports colors through a prefixed import', () async {
    const code = '''
import 'package:flutter/material.dart' as m;
final c = m.Colors.white;
''';
    await tester.expectLints(code, ['m.Colors.white']);
  });

  test('allows Colors.transparent', () async {
    await tester.expectNone('''
import 'package:flutter/material.dart';
final c = Colors.transparent;
''');
  });

  test('ignores a class named Colors outside Flutter', () async {
    await tester.expectNone('''
import 'package:flutter/material.dart';
abstract final class Colors {
  static const Color red = Color.fromARGB(255, 255, 0, 0);
}
final c = Colors.red;
''');
  });

  test('ignores files outside lib/', () async {
    await tester.expectNoneAt('test/widget_test.dart', '''
import 'package:flutter/material.dart';
final c = Colors.red;
''');
  });
}
