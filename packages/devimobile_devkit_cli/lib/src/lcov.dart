/// Line coverage of one source file.
final class FileCoverage {
  FileCoverage(this.path, [Map<int, int>? hits]) : hits = hits ?? {};

  /// Path as written in the `SF:` record.
  final String path;

  /// Execution count per line number.
  final Map<int, int> hits;

  int get linesFound => hits.length;
  int get linesHit => hits.values.where((count) => count > 0).length;

  /// Adds the counts of [other] to this file.
  void merge(FileCoverage other) {
    for (final MapEntry(key: line, value: count) in other.hits.entries) {
      hits[line] = (hits[line] ?? 0) + count;
    }
  }
}

/// Totals of a set of files.
final class CoverageTotals {
  const CoverageTotals(this.linesHit, this.linesFound);

  factory CoverageTotals.of(Iterable<FileCoverage> files) {
    var hit = 0;
    var found = 0;
    for (final file in files) {
      hit += file.linesHit;
      found += file.linesFound;
    }
    return CoverageTotals(hit, found);
  }

  final int linesHit;
  final int linesFound;

  /// Line coverage in percent; 100 when there is nothing to cover.
  double get percent => linesFound == 0 ? 100 : linesHit * 100 / linesFound;
}

/// Parses the line data (`SF`, `DA`, `end_of_record`) of an lcov report.
///
/// Other records (functions, branches, totals) are ignored: devkit measures
/// line coverage and recomputes totals itself.
List<FileCoverage> parseLcov(String content) {
  final files = <FileCoverage>[];
  FileCoverage? current;
  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      current = FileCoverage(line.substring(3));
      files.add(current);
    } else if (line.startsWith('DA:') && current != null) {
      final fields = line.substring(3).split(',');
      final number = fields.isNotEmpty ? int.tryParse(fields[0]) : null;
      final count = fields.length > 1 ? int.tryParse(fields[1]) : null;
      if (number == null || count == null) {
        throw FormatException('Invalid lcov line: $line');
      }
      current.hits[number] = (current.hits[number] ?? 0) + count;
    } else if (line == 'end_of_record') {
      current = null;
    }
  }
  return files;
}

/// Writes [files] as an lcov report, sorted by path.
String formatLcov(Iterable<FileCoverage> files) {
  final sorted = [...files]..sort((a, b) => a.path.compareTo(b.path));
  final out = StringBuffer();
  for (final file in sorted) {
    out.writeln('SF:${file.path}');
    final lines = file.hits.keys.toList()..sort();
    for (final line in lines) {
      out.writeln('DA:$line,${file.hits[line]}');
    }
    out
      ..writeln('LF:${file.linesFound}')
      ..writeln('LH:${file.linesHit}')
      ..writeln('end_of_record');
  }
  return out.toString();
}
