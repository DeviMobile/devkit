import 'package:devimobile_devkit_cli/src/errors.dart';
import 'package:yaml/yaml.dart';

/// Coverage settings from the `devkit:` key of a `pubspec.yaml`.
///
/// ```yaml
/// devkit:
///   coverage:
///     exclude:
///       - '**/*.g.dart'
///     min: 80
/// ```
///
/// In the workspace root, `exclude` globs match paths relative to the root;
/// in a package they match paths relative to that package. Lists from the
/// root and the package add up; a package's `min` replaces the root's.
final class CoverageConfig {
  const CoverageConfig({this.exclude = const [], this.min});

  /// Reads the `devkit:` key of a parsed pubspec. [source] names the file in
  /// error messages.
  factory CoverageConfig.fromPubspec(
    YamlMap pubspec, {
    required String source,
  }) {
    final devkit = pubspec['devkit'];
    if (devkit == null) {
      return const CoverageConfig();
    }
    final settings = _map(devkit, '$source: devkit', allowed: {'coverage'});
    final coverage = settings['coverage'];
    if (coverage == null) {
      return const CoverageConfig();
    }
    final map = _map(
      coverage,
      '$source: devkit.coverage',
      allowed: {'exclude', 'min'},
    );

    final exclude = <String>[];
    final rawExclude = map['exclude'];
    if (rawExclude != null) {
      if (rawExclude is! YamlList || rawExclude.any((e) => e is! String)) {
        throw DevkitException(
          '$source: devkit.coverage.exclude must be a list of glob strings',
        );
      }
      exclude.addAll(rawExclude.cast<String>());
    }

    final rawMin = map['min'];
    if (rawMin != null && (rawMin is! num || rawMin < 0 || rawMin > 100)) {
      throw DevkitException(
        '$source: devkit.coverage.min must be a number from 0 to 100',
      );
    }

    return CoverageConfig(
      exclude: List.unmodifiable(exclude),
      min: (rawMin as num?)?.toDouble(),
    );
  }

  /// Glob patterns of files left out of coverage.
  final List<String> exclude;

  /// Minimum line coverage in percent, or `null` for no threshold.
  final double? min;

  static YamlMap _map(
    Object? value,
    String where, {
    required Set<String> allowed,
  }) {
    if (value is! YamlMap) {
      throw DevkitException('$where must be a map');
    }
    for (final key in value.keys) {
      if (!allowed.contains(key)) {
        throw DevkitException(
          '$where: unknown key "$key" (allowed: ${allowed.join(', ')})',
        );
      }
    }
    return value;
  }
}
