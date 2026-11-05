import 'package:devimobile_devkit_cli/src/errors.dart';
import 'package:devimobile_devkit_cli/src/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late String root;

  setUp(() {
    root = tempDir();
    writeFile(root, 'pubspec.yaml', '''
name: root
environment:
  sdk: ^3.13.0
workspace:
  - apps/mobile
  - packages/*
devkit:
  coverage:
    min: 80
''');
    writeFile(
      root,
      'apps/mobile/pubspec.yaml',
      memberPubspec(
        'mobile',
        extra: '''
dependencies:
  flutter:
    sdk: flutter
''',
      ),
    );
    writeFile(root, 'apps/mobile/test/a_test.dart', '');
    writeFile(root, 'packages/core/pubspec.yaml', memberPubspec('core'));
    writeFile(root, 'packages/core/test/a_test.dart', '');
    writeFile(
      root,
      'packages/ui/pubspec.yaml',
      memberPubspec(
        'ui',
        extra: '''
dev_dependencies:
  flutter_test:
    sdk: flutter
devkit:
  coverage:
    exclude: ['lib/gen/**']
''',
      ),
    );
    writeFile(root, 'packages/not_a_package/README.md', '');
  });

  test('lists explicit and glob members sorted by path', () {
    final workspace = Workspace.discover(root);
    expect(workspace.root, root);
    expect(workspace.packages.map((package) => package.relativePath), [
      'apps/mobile',
      'packages/core',
      'packages/ui',
    ]);
    expect(workspace.coverage.min, 80);
  });

  test('detects the runner and tests of each package', () {
    final packages = {
      for (final package in Workspace.discover(root).packages)
        package.name: package,
    };
    expect(packages['mobile']!.runner, 'flutter');
    expect(packages['ui']!.runner, 'flutter');
    expect(packages['core']!.runner, 'dart');
    expect(packages['core']!.hasTests, isTrue);
    expect(packages['ui']!.hasTests, isFalse);
    expect(packages['ui']!.coverage.exclude, ['lib/gen/**']);
  });

  test('finds the workspace root from inside a member', () {
    final workspace = Workspace.discover(
      p.join(root, 'packages', 'core', 'test'),
    );
    expect(workspace.root, root);
    expect(workspace.packages, hasLength(3));
  });

  test('includes the root when it has tests of its own', () {
    writeFile(root, 'test/root_test.dart', '');
    final paths = Workspace.discover(root).packages.map((p) => p.relativePath);
    expect(paths.first, '.');
  });

  test('falls back to a single package without a workspace', () {
    final single = tempDir();
    writeFile(single, 'pubspec.yaml', 'name: single\n');
    writeFile(single, 'test/a_test.dart', '');
    final workspace = Workspace.discover(p.join(single, 'test'));
    expect(workspace.root, single);
    expect(workspace.packages.single.name, 'single');
    expect(workspace.packages.single.relativePath, '.');
  });

  test('reports a member without pubspec.yaml', () {
    writeFile(root, 'pubspec.yaml', '''
name: root
workspace:
  - packages/missing
''');
    expect(() => Workspace.discover(root), throwsA(isA<DevkitException>()));
  });
}
