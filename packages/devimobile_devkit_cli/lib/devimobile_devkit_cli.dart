/// The `devkit` command line tool: workspace-wide tests and coverage.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devimobile_devkit_cli/src/coverage_command.dart';
import 'package:devimobile_devkit_cli/src/errors.dart';
import 'package:devimobile_devkit_cli/src/fvm_check.dart';
import 'package:devimobile_devkit_cli/src/test_command.dart';

export 'package:devimobile_devkit_cli/src/coverage_command.dart'
    show CoverageReport, mergeCoverage;
export 'package:devimobile_devkit_cli/src/errors.dart' show DevkitException;
export 'package:devimobile_devkit_cli/src/fvm_check.dart'
    show FlutterVersionReader, checkFvm;
export 'package:devimobile_devkit_cli/src/workspace.dart'
    show Package, Workspace;

/// Runs `devkit` with [args] and returns the process exit code:
/// 0 success, 1 failed tests or coverage below minimum, 2 configuration or
/// environment error, 64 usage error.
Future<int> runDevkit(
  List<String> args, {
  String? workingDirectory,
  StringSink? out,
  StringSink? err,
  FlutterVersionReader readVersion = readFlutterVersion,
}) async {
  final cwd = workingDirectory ?? Directory.current.path;
  final output = out ?? stdout;
  final errors = err ?? stderr;
  final runner =
      CommandRunner<int>(
          'devkit',
          'Tests and coverage for Dart and Flutter pub workspaces.',
        )
        ..addCommand(
          TestCommand(
            workingDirectory: cwd,
            out: output,
            readVersion: readVersion,
          ),
        )
        ..addCommand(CoverageCommand(workingDirectory: cwd, out: output));
  try {
    return await runner.run(args) ?? 0;
  } on UsageException catch (e) {
    errors.writeln(e);
    return 64;
  } on DevkitException catch (e) {
    errors.writeln('devkit: ${e.message}');
    return 2;
  }
}
