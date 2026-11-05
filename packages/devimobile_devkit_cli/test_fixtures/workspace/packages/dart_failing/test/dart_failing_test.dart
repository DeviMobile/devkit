import 'package:dart_failing/dart_failing.dart';
import 'package:test/test.dart';

void main() {
  test('passes', () => expect(answer(), isPositive));
  test('answers 42', () => expect(answer(), 42));
}
