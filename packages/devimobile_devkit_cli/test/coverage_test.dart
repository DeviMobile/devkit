import 'dart:io';

import 'package:devimobile_devkit_cli/devimobile_devkit_cli.dart';
import 'package:devimobile_devkit_cli/src/lcov.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late String root;

  setUp(() {
    root = tempDir();
    writeFile(root, 'pubspec.yaml', '''
name: root
workspace:
  - packages/a
  - packages/b
  - packages/c
devkit:
  coverage:
    exclude: ['**/*.g.dart']
    min: 75
''');
    writeFile(
      root,
      'packages/a/pubspec.yaml',
      memberPubspec(
        'a',
        extra: '''
devkit:
  coverage:
    exclude: ['lib/gen/**']
    min: 40
''',
      ),
    );
    writeFile(root, 'packages/a/test/a_test.dart', '');
    // Relative paths, as written by `flutter test`.
    writeFile(root, 'packages/a/coverage/lcov.info', '''
SF:lib/a.dart
DA:1,1
DA:2,0
end_of_record
SF:lib/a.g.dart
DA:1,0
end_of_record
SF:lib/gen/messages.dart
DA:1,0
end_of_record
''');
    writeFile(root, 'packages/b/pubspec.yaml', memberPubspec('b'));
    writeFile(root, 'packages/b/test/b_test.dart', '');
    // Absolute paths, as written by `dart test --coverage-path`.
    writeFile(root, 'packages/b/coverage/lcov.info', '''
SF:${p.join(root, 'packages', 'b', 'lib', 'b.dart')}
DA:1,1
DA:2,1
DA:3,1
end_of_record
''');
    writeFile(root, 'packages/c/pubspec.yaml', memberPubspec('c'));
  });

  test('merges packages with root-relative paths and excludes', () {
    final report = mergeCoverage(Workspace.discover(root));
    expect(report.files.map((file) => file.path).toList()..sort(), [
      'packages/a/lib/a.dart',
      'packages/b/lib/b.dart',
    ]);
    expect(report.totals.linesHit, 4);
    expect(report.totals.linesFound, 5);
  });

  test('applies package minimum over the root one', () {
    final report = mergeCoverage(Workspace.discover(root));
    final byName = {
      for (final entry in report.packages) entry.package.name: entry,
    };
    expect(byName.keys, ['a', 'b']); // c has no tests
    expect(byName['a']!.min, 40);
    expect(byName['a']!.passes, isTrue); // 50% >= 40%
    expect(byName['b']!.min, 75);
    expect(report.totalPasses, isTrue); // 80% >= 75%
    expect(report.passes, isTrue);
  });

  test('--min overrides the root minimum', () async {
    final out = StringBuffer();
    final code = await runDevkit(
      ['coverage', '--min', '90'],
      workingDirectory: root,
      out: out,
    );
    expect(code, 1);
    expect(out.toString(), contains('BELOW MINIMUM'));
  });

  test('writes one merged lcov report', () async {
    final out = StringBuffer();
    final code = await runDevkit(
      ['coverage'],
      workingDirectory: root,
      out: out,
    );
    expect(code, 0, reason: out.toString());
    final merged = parseLcov(
      File(p.join(root, 'coverage', 'lcov.info')).readAsStringSync(),
    );
    expect(merged.map((file) => file.path), [
      'packages/a/lib/a.dart',
      'packages/b/lib/b.dart',
    ]);
  });

  test('fails with a hint when a tested package has no coverage', () async {
    File(p.join(root, 'packages', 'b', 'coverage', 'lcov.info')).deleteSync();
    final err = StringBuffer();
    final code = await runDevkit(
      ['coverage'],
      workingDirectory: root,
      out: StringBuffer(),
      err: err,
    );
    expect(code, 2);
    expect(err.toString(), contains('devkit test --coverage'));
  });
}
