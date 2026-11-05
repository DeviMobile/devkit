import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devimobile_devkit_cli/src/errors.dart';
import 'package:devimobile_devkit_cli/src/lcov.dart';
import 'package:devimobile_devkit_cli/src/table.dart';
import 'package:devimobile_devkit_cli/src/workspace.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// Coverage of one package after excludes.
final class PackageCoverage {
  const PackageCoverage({
    required this.package,
    required this.totals,
    required this.min,
  });

  final Package package;
  final CoverageTotals totals;

  /// Effective threshold: the package's own `min`, else the root's.
  final double? min;

  bool get passes => min == null || totals.percent >= min!;
}

/// Result of merging the coverage of a workspace.
final class CoverageReport {
  const CoverageReport({
    required this.files,
    required this.packages,
    required this.min,
  });

  /// Merged files, with paths relative to the workspace root.
  final List<FileCoverage> files;
  final List<PackageCoverage> packages;

  /// Threshold for the total.
  final double? min;

  CoverageTotals get totals => CoverageTotals.of(files);
  bool get totalPasses => min == null || totals.percent >= min!;
  bool get passes => totalPasses && packages.every((package) => package.passes);
}

/// Merges `<package>/coverage/lcov.info` of every tested package, applying
/// excludes and thresholds. [minOverride] replaces the root's `min`.
CoverageReport mergeCoverage(Workspace workspace, {double? minOverride}) {
  final rootExcludes = [
    for (final pattern in workspace.coverage.exclude)
      Glob(pattern, context: p.posix),
  ];
  final globalMin = minOverride ?? workspace.coverage.min;
  final merged = <String, FileCoverage>{};
  final packages = <PackageCoverage>[];
  final missing = <String>[];

  for (final package in workspace.packages) {
    if (!package.hasTests) {
      continue;
    }
    final lcov = File(p.join(package.directory, 'coverage', 'lcov.info'));
    if (!lcov.existsSync()) {
      missing.add(package.relativePath);
      continue;
    }
    final packageExcludes = [
      for (final pattern in package.coverage.exclude)
        Glob(pattern, context: p.posix),
    ];

    final included = <FileCoverage>[];
    for (final file in parseLcov(lcov.readAsStringSync())) {
      final absolute = p.normalize(
        p.isAbsolute(file.path)
            ? file.path
            : p.join(package.directory, file.path),
      );
      final fromRoot = _posix(p.relative(absolute, from: workspace.root));
      final fromPackage = _posix(p.relative(absolute, from: package.directory));
      if (rootExcludes.any((glob) => glob.matches(fromRoot)) ||
          packageExcludes.any((glob) => glob.matches(fromPackage))) {
        continue;
      }
      final normalized = FileCoverage(fromRoot, {...file.hits});
      included.add(normalized);
      merged.putIfAbsent(fromRoot, () => FileCoverage(fromRoot)).merge(file);
    }
    packages.add(
      PackageCoverage(
        package: package,
        totals: CoverageTotals.of(included),
        min: package.coverage.min ?? globalMin,
      ),
    );
  }

  if (missing.isNotEmpty) {
    throw DevkitException(
      'No coverage/lcov.info in: ${missing.join(', ')}. '
      'Run `devkit test --coverage` first.',
    );
  }
  return CoverageReport(
    files: merged.values.toList(),
    packages: packages,
    min: globalMin,
  );
}

String _posix(String path) => path.replaceAll(r'\', '/');

/// `devkit coverage`: merges package coverage into one lcov report and
/// enforces thresholds.
final class CoverageCommand extends Command<int> {
  CoverageCommand({required this.workingDirectory, required this.out}) {
    argParser
      ..addOption(
        'output',
        abbr: 'o',
        defaultsTo: p.join('coverage', 'lcov.info'),
        help: 'Merged lcov report, relative to the workspace root.',
      )
      ..addOption(
        'min',
        help: 'Minimum total line coverage in percent; overrides devkit.coverage.min of the root pubspec.yaml.',
      );
  }

  final String workingDirectory;
  final StringSink out;

  @override
  String get name => 'coverage';

  @override
  String get description =>
      'Merge the coverage of all packages (from `devkit test --coverage`) '
      'into one lcov report and check thresholds.';

  @override
  Future<int> run() async {
    final args = argResults!;
    final rawMin = args['min'] as String?;
    final min = rawMin == null ? null : double.tryParse(rawMin);
    if (rawMin != null && (min == null || min < 0 || min > 100)) {
      usageException('--min must be a number from 0 to 100');
    }

    final workspace = Workspace.discover(workingDirectory);
    final report = mergeCoverage(workspace, minOverride: min);

    final output = File(p.join(workspace.root, args['output'] as String));
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(formatLcov(report.files));

    String percent(CoverageTotals totals) =>
        totals.linesFound == 0 ? '-' : '${totals.percent.toStringAsFixed(1)}%';
    String threshold(double? value) =>
        value == null ? '-' : '${value.toStringAsFixed(1)}%';

    final rows = [
      for (final entry in report.packages)
        [
          entry.package.name,
          '${entry.totals.linesHit}/${entry.totals.linesFound}',
          percent(entry.totals),
          threshold(entry.min),
          if (entry.passes) 'ok' else 'BELOW MINIMUM',
        ],
      [
        'total',
        '${report.totals.linesHit}/${report.totals.linesFound}',
        percent(report.totals),
        threshold(report.min),
        if (report.totalPasses) 'ok' else 'BELOW MINIMUM',
      ],
    ];
    out
      ..writeln(
        formatTable(
          ['Package', 'Lines', 'Coverage', 'Minimum', 'Result'],
          rows,
          rightAligned: {1, 2, 3},
        ),
      )
      ..writeln()
      ..writeln(
        'Wrote ${p.relative(output.path, from: workspace.root)} '
        '(${report.files.length} files).',
      );
    return report.passes ? 0 : 1;
  }
}
