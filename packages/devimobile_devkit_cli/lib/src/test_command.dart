import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devimobile_devkit_cli/src/fvm_check.dart';
import 'package:devimobile_devkit_cli/src/table.dart';
import 'package:devimobile_devkit_cli/src/test_report.dart';
import 'package:devimobile_devkit_cli/src/workspace.dart';
import 'package:path/path.dart' as p;

/// `devkit test`: runs the tests of every workspace package.
final class TestCommand extends Command<int> {
  TestCommand({
    required this.workingDirectory,
    required this.out,
    this.readVersion = readFlutterVersion,
  }) {
    argParser
      ..addFlag(
        'coverage',
        negatable: false,
        help: 'Write line coverage of each package to <package>/coverage/lcov.info.',
      )
      ..addOption(
        'jobs',
        abbr: 'j',
        defaultsTo: '1',
        help: 'How many packages to test at the same time.',
      )
      ..addFlag(
        'fvm-check',
        defaultsTo: true,
        help: 'Fail when .fvmrc pins a Flutter version other than the one on PATH.',
      );
  }

  final String workingDirectory;
  final StringSink out;
  final FlutterVersionReader readVersion;

  @override
  String get name => 'test';

  @override
  String get description =>
      'Run the tests of every package in the workspace and summarize them.\n\n'
      'Arguments after `--` are passed to `dart test` / `flutter test`.';

  @override
  String get invocation => 'devkit test [options] [-- <test runner arguments>]';

  @override
  Future<int> run() async {
    final args = argResults!;
    final jobs = int.tryParse(args['jobs'] as String);
    if (jobs == null || jobs < 1) {
      usageException('--jobs must be a positive integer');
    }
    final coverage = args['coverage'] as bool;
    final passThrough = args.rest;

    final workspace = Workspace.discover(workingDirectory);
    if (args['fvm-check'] as bool) {
      await checkFvm(workspace.root, readVersion: readVersion);
    }

    final testable = [
      for (final package in workspace.packages)
        if (package.hasTests) package,
    ];
    final results = List<_PackageResult?>.filled(testable.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < testable.length) {
        final index = next++;
        final result = await _runPackage(
          testable[index],
          coverage: coverage,
          passThrough: passThrough,
        );
        results[index] = result;
        out
          ..writeln(
            '── ${result.package.name} (${result.package.runner} test) ──',
          )
          ..write(result.output)
          ..writeln();
      }
    }

    await Future.wait([for (var i = 0; i < jobs; i++) worker()]);

    final finished = results.whereType<_PackageResult>().toList();
    _printSummary(workspace, finished);
    final failed = finished.where((result) => !result.success).toList();
    if (failed.isEmpty) {
      out.writeln('All ${finished.length} tested packages passed.');
      return 0;
    }
    out.writeln(
      '${failed.length} of ${finished.length} tested packages failed: '
      '${failed.map((result) => result.package.name).join(', ')}',
    );
    return 1;
  }

  Future<_PackageResult> _runPackage(
    Package package, {
    required bool coverage,
    required List<String> passThrough,
  }) async {
    final reportFile = File(
      p.join(package.directory, '.dart_tool', 'devkit', 'test-report.json'),
    );
    final lcovFile = File(p.join(package.directory, 'coverage', 'lcov.info'));
    for (final stale in [reportFile, if (coverage) lcovFile]) {
      if (stale.existsSync()) {
        stale.deleteSync();
      }
    }
    reportFile.parent.createSync(recursive: true);

    final arguments = [
      'test',
      '--file-reporter',
      'json:${reportFile.path}',
      if (coverage) ...[
        if (package.usesFlutter) '--coverage',
        '--coverage-path=${lcovFile.path}',
      ],
      ...passThrough,
    ];

    final stopwatch = Stopwatch()..start();
    final output = StringBuffer();
    int exitCode;
    try {
      final process = await Process.start(
        package.runner,
        arguments,
        workingDirectory: package.directory,
        runInShell: Platform.isWindows,
      );
      await Future.wait([
        process.stdout.transform(utf8.decoder).forEach(output.write),
        process.stderr.transform(utf8.decoder).forEach(output.write),
      ]);
      exitCode = await process.exitCode;
    } on ProcessException catch (e) {
      output.writeln('Could not start `${package.runner}`: ${e.message}');
      exitCode = -1;
    }
    stopwatch.stop();

    final report = reportFile.existsSync()
        ? parseTestReport(reportFile.readAsStringSync())
        : null;
    return _PackageResult(
      package: package,
      exitCode: exitCode,
      report: report,
      output: output.toString(),
      elapsed: stopwatch.elapsed,
    );
  }

  void _printSummary(Workspace workspace, List<_PackageResult> results) {
    final byName = {for (final result in results) result.package.name: result};
    final rows = <List<String>>[];
    for (final package in workspace.packages) {
      final result = byName[package.name];
      if (result == null) {
        rows.add([
          package.name,
          package.relativePath,
          '',
          '',
          '',
          '',
          '',
          'no tests',
        ]);
        continue;
      }
      final report = result.report;
      rows.add([
        package.name,
        package.relativePath,
        package.runner,
        '${report?.passed ?? '-'}',
        '${report?.failed ?? '-'}',
        '${report?.skipped ?? '-'}',
        '${(result.elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s',
        result.status,
      ]);
    }
    out
      ..writeln()
      ..writeln(
        formatTable(
          [
            'Package',
            'Path',
            'Runner',
            'Passed',
            'Failed',
            'Skipped',
            'Time',
            'Result',
          ],
          rows,
          rightAligned: {3, 4, 5, 6},
        ),
      )
      ..writeln();

    for (final result in results) {
      final failures = result.report?.failures ?? const <String>[];
      if (failures.isNotEmpty) {
        out.writeln('Failed in ${result.package.name}:');
        for (final failure in failures) {
          out.writeln('  - $failure');
        }
        out.writeln();
      }
    }
  }
}

final class _PackageResult {
  const _PackageResult({
    required this.package,
    required this.exitCode,
    required this.report,
    required this.output,
    required this.elapsed,
  });

  final Package package;
  final int exitCode;
  final TestReport? report;
  final String output;
  final Duration elapsed;

  /// Passing needs both a zero exit code and a complete report without
  /// failures, so neither a crashed runner nor a misreported exit code can
  /// turn a failure into a pass.
  bool get success => exitCode == 0 && (report?.success ?? false);

  String get status {
    final report = this.report;
    if (report == null) {
      return 'FAILED (no report, exit $exitCode)';
    }
    if (!report.completed) {
      return 'FAILED (run did not finish, exit $exitCode)';
    }
    if (report.failed > 0) {
      return 'FAILED';
    }
    return exitCode == 0 ? 'ok' : 'FAILED (exit $exitCode)';
  }
}
