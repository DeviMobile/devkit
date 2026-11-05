import 'package:dart_ok/dart_ok.dart';
import 'package:dart_ok/generated.dart';
import 'package:test/test.dart';

void main() {
  test('adds', () => expect(add(1, 2), 3));
  test('loads generated code', () => expect(generated, isNotNull));
  test('is skipped', () {}, skip: 'example of a skipped test');
}
