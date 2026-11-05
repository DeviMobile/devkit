import 'dart:convert';
import 'dart:io';

import 'package:devimobile_devkit_cli/src/errors.dart';
import 'package:path/path.dart' as p;

/// Returns the version of the `flutter` on `PATH`, or `null` if there is none.
typedef FlutterVersionReader = Future<String?> Function();

/// Runs `flutter --version --machine`.
Future<String?> readFlutterVersion() async {
  final ProcessResult result;
  try {
    result = await Process.run('flutter', [
      '--version',
      '--machine',
    ], runInShell: Platform.isWindows);
  } on ProcessException {
    return null;
  }
  if (result.exitCode != 0) {
    return null;
  }
  final output = result.stdout as String;
  final start = output.indexOf('{');
  if (start < 0) {
    return null;
  }
  try {
    final json = jsonDecode(output.substring(start)) as Map<String, Object?>;
    final version = json['frameworkVersion'];
    return version is String ? version : null;
  } on FormatException {
    return null;
  }
}

/// Fails when `.fvmrc` in [root] pins a Flutter version other than the one
/// on `PATH`. Does nothing without `.fvmrc` or when it pins a channel.
Future<void> checkFvm(
  String root, {
  FlutterVersionReader readVersion = readFlutterVersion,
}) async {
  final file = File(p.join(root, '.fvmrc'));
  if (!file.existsSync()) {
    return;
  }
  final Object? config;
  try {
    config = jsonDecode(file.readAsStringSync());
  } on FormatException catch (e) {
    throw DevkitException('.fvmrc is not valid JSON: ${e.message}');
  }
  final pinned = config is Map<String, Object?> ? config['flutter'] : null;
  if (pinned is! String || !RegExp(r'^\d+\.\d+\.\d+').hasMatch(pinned)) {
    return;
  }

  final hint =
      'Run devkit through FVM (`fvm exec devkit ...`), put Flutter $pinned on '
      'PATH, or pass --no-fvm-check.';
  final actual = await readVersion();
  if (actual == null) {
    throw DevkitException(
      '.fvmrc pins Flutter $pinned, but there is no `flutter` on PATH.\n$hint',
    );
  }
  if (actual != pinned) {
    throw DevkitException(
      '.fvmrc pins Flutter $pinned, but `flutter` on PATH is $actual.\n$hint',
    );
  }
}
