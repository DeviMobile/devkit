// Generates lib/core.yaml, lib/strict.yaml and RULES.md from
// tool/decisions.yaml and tool/sdk_rules.json.
//
//   dart run tool/generate.dart          write the files
//   dart run tool/generate.dart --check  fail if they are out of date
import 'dart:io';

import 'src/catalog.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  final root = Directory.fromUri(Platform.script.resolve('..'));
  String read(String path) => File('${root.path}$path').readAsStringSync();

  final catalog = SdkCatalog.parse(read('tool/sdk_rules.json'));
  final decisions = parseDecisions(read('tool/decisions.yaml'));

  final problems = validate(catalog, decisions);
  if (problems.isNotEmpty) {
    stderr.writeln('tool/decisions.yaml has ${problems.length} problem(s):');
    for (final problem in problems) {
      stderr.writeln('  - $problem');
    }
    exitCode = 1;
    return;
  }

  final stale = <String>[];
  final outputs = renderOutputs(catalog, decisions);
  for (final MapEntry(key: path, value: content) in outputs.entries) {
    final file = File('${root.path}$path');
    final current = file.existsSync() ? file.readAsStringSync() : null;
    if (current == content) {
      continue;
    }
    if (check) {
      stale.add(path);
    } else {
      file.writeAsStringSync(content);
      stdout.writeln('wrote $path');
    }
  }

  if (stale.isNotEmpty) {
    stderr.writeln(
      'Out of date: ${stale.join(', ')}. Run `dart run tool/generate.dart`.',
    );
    exitCode = 1;
  }
}
