import 'package:devimobile_devkit_cli/src/errors.dart';
import 'package:devimobile_devkit_cli/src/fvm_check.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  FlutterVersionReader version(String? value) =>
      () async => value;

  test('passes without .fvmrc', () async {
    await checkFvm(tempDir(), readVersion: version(null));
  });

  test('passes when .fvmrc pins a channel', () async {
    final root = tempDir();
    writeFile(root, '.fvmrc', '{"flutter": "stable"}');
    await checkFvm(root, readVersion: version('3.47.9'));
  });

  test('passes when versions match', () async {
    final root = tempDir();
    writeFile(root, '.fvmrc', '{"flutter": "3.47.9"}');
    await checkFvm(root, readVersion: version('3.47.9'));
  });

  test('fails with both versions and a hint when they differ', () async {
    final root = tempDir();
    writeFile(root, '.fvmrc', '{"flutter": "3.47.9"}');
    await expectLater(
      checkFvm(root, readVersion: version('3.41.0')),
      throwsA(
        isA<DevkitException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('3.47.9'),
            contains('3.41.0'),
            contains('fvm exec'),
            contains('--no-fvm-check'),
          ),
        ),
      ),
    );
  });

  test('fails when flutter is not on PATH', () async {
    final root = tempDir();
    writeFile(root, '.fvmrc', '{"flutter": "3.47.9"}');
    await expectLater(
      checkFvm(root, readVersion: version(null)),
      throwsA(
        isA<DevkitException>().having(
          (e) => e.message,
          'message',
          contains('no `flutter` on PATH'),
        ),
      ),
    );
  });
}
