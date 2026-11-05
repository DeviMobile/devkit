import 'package:devimobile_devkit_cli/src/config.dart';
import 'package:devimobile_devkit_cli/src/errors.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

CoverageConfig parse(String yaml) => CoverageConfig.fromPubspec(
  loadYaml(yaml) as YamlMap,
  source: 'pubspec.yaml',
);

Matcher throwsDevkit(String message) => throwsA(
  isA<DevkitException>().having((e) => e.message, 'message', contains(message)),
);

void main() {
  test('missing devkit key gives an empty config', () {
    final config = parse('name: a\n');
    expect(config.exclude, isEmpty);
    expect(config.min, isNull);
  });

  test('reads excludes and minimum', () {
    final config = parse('''
devkit:
  coverage:
    exclude: ['**/*.g.dart', 'lib/l10n/**']
    min: 85
''');
    expect(config.exclude, ['**/*.g.dart', 'lib/l10n/**']);
    expect(config.min, 85.0);
  });

  test('rejects unknown keys so typos do not pass silently', () {
    expect(
      () => parse('devkit:\n  coverage:\n    minimum: 80\n'),
      throwsDevkit('unknown key "minimum"'),
    );
    expect(
      () => parse('devkit:\n  coverge: {}\n'),
      throwsDevkit('unknown key "coverge"'),
    );
  });

  test('rejects invalid values', () {
    expect(
      () => parse('devkit:\n  coverage:\n    min: 120\n'),
      throwsDevkit('from 0 to 100'),
    );
    expect(
      () => parse('devkit:\n  coverage:\n    exclude: lib/**\n'),
      throwsDevkit('list of glob strings'),
    );
  });
}
