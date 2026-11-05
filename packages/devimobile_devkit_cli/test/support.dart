import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Creates a temporary directory deleted after the current test.
String tempDir() {
  final dir = Directory.systemTemp.createTempSync('devkit_test_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir.resolveSymbolicLinksSync();
}

/// Writes [content] to [path] under [root], creating parent directories.
void writeFile(String root, String path, String content) {
  File(p.join(root, path))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);
}

/// A minimal pubspec for a workspace member.
String memberPubspec(String name, {String extra = ''}) =>
    'name: $name\n'
    'environment:\n'
    '  sdk: ^3.13.0\n'
    'resolution: workspace\n'
    '$extra';
