import 'dart:io';

import 'package:devimobile_devkit_cli/src/config.dart';
import 'package:devimobile_devkit_cli/src/errors.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// One Dart or Flutter package of the workspace.
final class Package {
  const Package({
    required this.name,
    required this.directory,
    required this.relativePath,
    required this.usesFlutter,
    required this.hasTests,
    required this.coverage,
  });

  final String name;

  /// Absolute path.
  final String directory;

  /// Path relative to the workspace root, with `/` separators (`.` for the
  /// root itself).
  final String relativePath;

  /// Whether the package depends on the Flutter SDK, so it runs under
  /// `flutter test` rather than `dart test`.
  final bool usesFlutter;

  /// Whether the package has a `test/` directory.
  final bool hasTests;

  /// Package-level coverage settings.
  final CoverageConfig coverage;

  String get runner => usesFlutter ? 'flutter' : 'dart';
}

/// The packages devkit works on: the members of a pub workspace, or a single
/// package when there is no workspace.
final class Workspace {
  const Workspace({
    required this.root,
    required this.packages,
    required this.coverage,
  });

  /// Finds the workspace containing [start]: the closest ancestor whose
  /// `pubspec.yaml` has a `workspace:` key, or else the closest package.
  factory Workspace.discover(String start) {
    final from = p.normalize(p.absolute(start));
    String? nearest;
    String? workspaceRoot;
    for (var current = from; ; current = p.dirname(current)) {
      if (File(p.join(current, 'pubspec.yaml')).existsSync()) {
        nearest ??= current;
        if (_readPubspec(current).containsKey('workspace')) {
          workspaceRoot = current;
          break;
        }
      }
      if (p.dirname(current) == current) {
        break;
      }
    }

    final root =
        workspaceRoot ??
        nearest ??
        (throw DevkitException('No pubspec.yaml in $from or its parents'));
    final rootPubspec = _readPubspec(root);
    final coverage = CoverageConfig.fromPubspec(
      rootPubspec,
      source: 'pubspec.yaml',
    );

    if (workspaceRoot == null) {
      return Workspace(
        root: root,
        packages: [_readPackage(root, root, rootPubspec)],
        coverage: coverage,
      );
    }

    final memberDirs = <String>{
      if (Directory(p.join(root, 'test')).existsSync()) root,
      ..._memberDirectories(root, rootPubspec['workspace']),
    };
    final packages = [
      for (final dir in memberDirs) _readPackage(root, dir, _readPubspec(dir)),
    ]..sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return Workspace(root: root, packages: packages, coverage: coverage);
  }

  /// Absolute path of the workspace root.
  final String root;
  final List<Package> packages;

  /// Root-level coverage settings.
  final CoverageConfig coverage;
}

Iterable<String> _memberDirectories(String root, Object? entries) sync* {
  if (entries is! YamlList || entries.any((e) => e is! String)) {
    throw const DevkitException(
      'pubspec.yaml: workspace must be a list of paths',
    );
  }
  for (final entry in entries.cast<String>()) {
    if (entry.contains(RegExp(r'[*?\[{]'))) {
      final matches = Glob(entry, context: p.posix).listSync(root: root);
      final dirs = [
        for (final match in matches)
          if (match is Directory &&
              File(p.join(match.path, 'pubspec.yaml')).existsSync())
            p.normalize(match.path),
      ]..sort();
      yield* dirs;
    } else {
      final dir = p.normalize(p.join(root, entry));
      if (!File(p.join(dir, 'pubspec.yaml')).existsSync()) {
        throw DevkitException(
          'pubspec.yaml: workspace member "$entry" has no pubspec.yaml',
        );
      }
      yield dir;
    }
  }
}

Package _readPackage(String root, String dir, YamlMap pubspec) {
  final relative = p.relative(dir, from: root).replaceAll(r'\', '/');
  final name = pubspec['name'];
  if (name is! String) {
    throw DevkitException('$relative/pubspec.yaml: missing name');
  }
  return Package(
    name: name,
    directory: dir,
    relativePath: relative,
    usesFlutter: _dependsOnFlutter(pubspec),
    hasTests: Directory(p.join(dir, 'test')).existsSync(),
    coverage: CoverageConfig.fromPubspec(
      pubspec,
      source: relative == '.' ? 'pubspec.yaml' : '$relative/pubspec.yaml',
    ),
  );
}

bool _dependsOnFlutter(YamlMap pubspec) {
  for (final section in ['dependencies', 'dev_dependencies']) {
    final dependencies = pubspec[section];
    if (dependencies is! YamlMap) {
      continue;
    }
    for (final name in ['flutter', 'flutter_test']) {
      final dependency = dependencies[name];
      if (dependency is YamlMap && dependency['sdk'] == 'flutter') {
        return true;
      }
    }
  }
  return false;
}

YamlMap _readPubspec(String dir) {
  final file = File(p.join(dir, 'pubspec.yaml'));
  final Object? content;
  try {
    content = loadYaml(file.readAsStringSync(), sourceUrl: file.uri);
  } on YamlException catch (e) {
    throw DevkitException('${file.path}: ${e.message}');
  }
  if (content is! YamlMap) {
    throw DevkitException('${file.path}: expected a map');
  }
  return content;
}
