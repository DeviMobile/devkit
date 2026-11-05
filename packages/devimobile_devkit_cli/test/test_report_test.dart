import 'dart:convert';

import 'package:devimobile_devkit_cli/src/test_report.dart';
import 'package:test/test.dart';

String events(List<Map<String, Object?>> list) =>
    list.map(jsonEncode).join('\n');

Map<String, Object?> start(int id, String name) => {
  'type': 'testStart',
  'test': {'id': id, 'name': name, 'suiteID': 0},
};

Map<String, Object?> done(
  int id,
  String result, {
  bool hidden = false,
  bool skipped = false,
}) => {
  'type': 'testDone',
  'testID': id,
  'result': result,
  'hidden': hidden,
  'skipped': skipped,
};

void main() {
  test('counts passed, failed and skipped tests', () {
    final report = parseTestReport(
      events([
        start(1, 'loading test/a_test.dart'),
        done(1, 'success', hidden: true),
        start(2, 'adds'),
        done(2, 'success'),
        start(3, 'subtracts'),
        done(3, 'failure'),
        start(4, 'later'),
        done(4, 'success', skipped: true),
        {'type': 'done', 'success': false},
      ]),
    );
    expect(report.passed, 1);
    expect(report.failed, 1);
    expect(report.skipped, 1);
    expect(report.failures, ['subtracts']);
    expect(report.completed, isTrue);
    expect(report.success, isFalse);
  });

  test('counts a suite that fails to load as a failure', () {
    final report = parseTestReport(
      events([
        start(1, 'loading test/broken_test.dart'),
        done(1, 'error', hidden: true),
        {'type': 'done', 'success': false},
      ]),
    );
    expect(report.failures, ['loading test/broken_test.dart']);
    expect(report.success, isFalse);
  });

  test('a report without a done event is not a success', () {
    final report = parseTestReport(events([start(1, 'a'), done(1, 'success')]));
    expect(report.passed, 1);
    expect(report.completed, isFalse);
    expect(report.success, isFalse);
  });

  test('skips lines that are not JSON events', () {
    final report = parseTestReport(
      'Observatory listening\n'
      '${events([
        start(1, 'a'),
        done(1, 'success'),
        {'type': 'done', 'success': true},
      ])}\n',
    );
    expect(report.success, isTrue);
  });
}
