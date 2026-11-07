import 'package:devimobile_devkit_rules/src/rules/avoid_ui_string_literals.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final tester = RuleTester(AvoidUiStringLiterals.new);

  test('reports the text of Text, const or not', () async {
    const code = '''
import 'package:flutter/material.dart';
const a = Text('Hello');
final b = Text("Sign in", maxLines: 1);
''';
    await tester.expectLints(
      code,
      ["'Hello'", '"Sign in"'],
      messageContainsAll: ['Text'],
    );
  });

  test('reports the text when a named argument comes first', () async {
    const code = '''
import 'package:flutter/material.dart';
const a = Text(maxLines: 1, 'Hello');
''';
    await tester.expectLints(code, ["'Hello'"]);
  });

  test('reports the named text parameters of Flutter APIs', () async {
    const code = '''
import 'package:flutter/material.dart';
const a = Text('', semanticsLabel: 'Close');
const b = Icon(Icons.book, semanticLabel: 'Add');
const c = IconButton(icon: Text(''), tooltip: 'Back');
const d = InputDecoration(hintText: 'Email', labelText: 'Login');
''';
    await tester.expectLints(code, [
      "'Close'",
      "'Add'",
      "'Back'",
      "'Email'",
      "'Login'",
    ]);
  });

  test('reports interpolated, adjacent and conditional literals', () async {
    const code = r'''
import 'package:flutter/material.dart';
Text greet(String name) => Text('Hello $name');
const adjacent = Text('Hello ' 'world');
Text answer(bool ok) => Text(ok ? 'Yes' : 'No');
''';
    await tester.expectLints(code, [
      r"'Hello $name'",
      "'Hello ' 'world'",
      "'Yes'",
      "'No'",
    ]);
  });

  test('reports text in any script', () async {
    const code = '''
import 'package:flutter/material.dart';
const a = Text('Zażółć gęślą jaźń');
const b = Text('東京');
''';
    await tester.expectLints(code, ["'Zażółć gęślą jaźń'", "'東京'"]);
  });

  test('allows literals without letters', () async {
    await tester.expectNone(r'''
import 'package:flutter/material.dart';
const empty = Text('');
const space = Text(' ');
const bullet = Text('•');
const digits = Text('42');
Text count(int n) => Text('$n');
Text ratio(int a, int b) => Text('$a / $b');
''');
  });

  test('allows variables and other string parameters', () async {
    await tester.expectNone('''
import 'package:flutter/material.dart';
Text label(String text) => Text(text);
const tip = Tooltip(message: 'Not checked by this rule');
const helper = InputDecoration(helperText: 'Not checked either');
const key = ValueKey('login_submit');
''');
  });

  test('follows super parameters to the Flutter API', () async {
    const code = '''
import 'package:flutter/material.dart';
class BackButton extends IconButton {
  const BackButton({super.tooltip}) : super(icon: const Text(''));
}
const a = BackButton(tooltip: 'Back');
''';
    await tester.expectLints(code, ["'Back'"]);
  });

  test('ignores a widget named Text from another library', () async {
    tester.addOtherPackageFile('lib/text.dart', '''
class Text {
  const Text(String data, {String? tooltip});
}
''');
    await tester.expectNone('''
import 'package:other_ui/text.dart';
const a = Text('Hello', tooltip: 'Hi');
''');
  });

  test('ignores own parameters named like Flutter ones', () async {
    await tester.expectNone('''
class Field {
  const Field({String? hintText});
}
const a = Field(hintText: 'Email');
''');
  });

  test('ignores files outside lib/', () async {
    await tester.expectNoneAt('test/widget_test.dart', '''
import 'package:flutter/material.dart';
const a = Text('Hello');
''');
  });
}
