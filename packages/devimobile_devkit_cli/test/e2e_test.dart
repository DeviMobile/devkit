@Tags(['e2e'])
library;

import 'dart:io';

import 'package:devimobile_devkit_cli/devimobile_devkit_cli.dart';
import 'package:devimobile_devkit_cli/src/lcov.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

/// Runs devkit on a copy of `test_fixtures/workspace`: a Dart package that
/// passes, one with a failing test, a Flutter package and one without tests.
/// Needs `flutter` on PATH; resolving the fixture may use the network.
void main() {
  late String root;

  setUpAll(() async {
    root = await _copyFixture();
    final result = await Process.run(
      'flutter',
      ['pub', 'get'],
      workingDirectory: root,
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) {
      fail('flutter pub get failed:\n${result.stdout}\n${result.stderr}');
    }
  });

  test('test: fails, names the failing package and summarizes all', () async {
    final out = StringBuffer();
    final code = await runDevkit(
      ['test', '--coverage', '--no-fvm-check'],
      workingDirectory: root,
      out: out,
    );
    final output = out.toString();
    expect(code, 1, reason: output);
    expect(output, contains('1 of 3 tested packages failed: dart_failing'));
    expect(output, contains('Failed in dart_failing:\n  - answers 42'));
    expect(
      output,
      matches(
        RegExp(r'dart_ok\s+packages/dart_ok\s+dart\s+2\s+0\s+1\s+\S+\s+ok'),
      ),
    );
    expect(
      output,
      matches(
        RegExp(
          r'flutter_ok\s+packages/flutter_ok\s+flutter\s+1\s+0\s+0\s+\S+\s+ok',
        ),
      ),
    );
    expect(output, matches(RegExp(r'no_tests\s+packages/no_tests\s+no tests')));
  });

  test('coverage: one lcov with excludes, total below minimum', () async {
    final out = StringBuffer();
    final code = await runDevkit(
      ['coverage'],
      workingDirectory: root,
      out: out,
    );
    final output = out.toString();
    expect(code, 1, reason: output);

    final paths = parseLcov(
      File(p.join(root, 'coverage', 'lcov.info')).readAsStringSync(),
    ).map((file) => file.path);
    expect(paths, contains('packages/dart_ok/lib/dart_ok.dart'));
    expect(paths, contains('packages/flutter_ok/lib/flutter_ok.dart'));
    expect(paths, isNot(contains('packages/dart_ok/lib/generated.dart')));

    // dart_ok covers 1 of 2 lines: above its own minimum (40%), while the
    // total stays below the root minimum (90%).
    expect(output, matches(RegExp(r'dart_ok\s+1/2\s+50\.0%\s+40\.0%\s+ok')));
    expect(output, matches(RegExp(r'total\s+.*90\.0%\s+BELOW MINIMUM')));
  });

  test('test: a mismatched .fvmrc stops with a readable error', () async {
    writeFile(root, '.fvmrc', '{"flutter": "1.0.0"}');
    addTearDown(() => File(p.join(root, '.fvmrc')).deleteSync());
    final err = StringBuffer();
    final code = await runDevkit(
      ['test'],
      workingDirectory: root,
      out: StringBuffer(),
      err: err,
    );
    expect(code, 2);
    expect(
      err.toString(),
      allOf(contains('.fvmrc pins Flutter 1.0.0'), contains('--no-fvm-check')),
    );
  });
}

Future<String> _copyFixture() async {
  final source = Directory(p.join('test_fixtures', 'workspace'));
  final target = tempDir();
  await for (final entity in source.list(recursive: true)) {
    if (entity is File) {
      final relative = p.relative(entity.path, from: source.path);
      writeFile(target, relative, entity.readAsStringSync());
    }
  }
  return target;
}
