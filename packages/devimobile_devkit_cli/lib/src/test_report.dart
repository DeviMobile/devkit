import 'dart:convert';

/// Outcome of one test runner invocation, read from its JSON report file
/// (https://dart.dev/go/test-docs/json_reporter.md).
final class TestReport {
  const TestReport({
    required this.passed,
    required this.failed,
    required this.skipped,
    required this.failures,
    required this.completed,
  });

  final int passed;

  /// Failed or errored tests, including suites that failed to load.
  final int failed;
  final int skipped;

  /// Names of the failed tests.
  final List<String> failures;

  /// Whether the report ends with a `done` event, i.e. the run finished.
  final bool completed;

  bool get success => completed && failed == 0;
}

/// Reads a JSON reporter file written by `dart test` or `flutter test`.
///
/// The file is read after the process ends, so events are never split across
/// partial output chunks.
TestReport parseTestReport(String content) {
  final names = <int, String>{};
  final failures = <String>[];
  var passed = 0;
  var skipped = 0;
  var completed = false;

  for (final line in const LineSplitter().convert(content)) {
    if (line.trim().isEmpty) {
      continue;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      continue; // Not an event (e.g. a stray line from a crashing runner).
    }
    if (decoded is! Map<String, Object?>) {
      continue;
    }
    switch (decoded['type']) {
      case 'testStart':
        final test = decoded['test'];
        if (test is Map<String, Object?>) {
          final id = test['id'];
          final name = test['name'];
          if (id is int && name is String) {
            names[id] = name;
          }
        }
      case 'testDone':
        final id = decoded['testID'];
        final result = decoded['result'];
        final hidden = decoded['hidden'] == true;
        if (result != 'success') {
          failures.add(names[id] ?? 'test #$id');
        } else if (decoded['skipped'] == true) {
          skipped++;
        } else if (!hidden) {
          passed++;
        }
      case 'done':
        completed = true;
    }
  }

  return TestReport(
    passed: passed,
    failed: failures.length,
    skipped: skipped,
    failures: List.unmodifiable(failures),
    completed: completed,
  );
}
