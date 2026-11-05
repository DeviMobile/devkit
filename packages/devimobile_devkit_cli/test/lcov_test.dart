import 'package:devimobile_devkit_cli/src/lcov.dart';
import 'package:test/test.dart';

void main() {
  const sample = '''
SF:lib/a.dart
FN:1,main
DA:1,3
DA:2,0
LF:2
LH:1
end_of_record
SF:lib/b.dart
DA:5,1,abc123
end_of_record
''';

  test('parses line data and ignores other records', () {
    final files = parseLcov(sample);
    expect(files.map((file) => file.path), ['lib/a.dart', 'lib/b.dart']);
    expect(files[0].hits, {1: 3, 2: 0});
    expect(files[1].hits, {5: 1});
  });

  test('rejects malformed DA records', () {
    expect(
      () => parseLcov('SF:a.dart\nDA:x,1\nend_of_record\n'),
      throwsFormatException,
    );
  });

  test('merge adds hit counts per line', () {
    final file = FileCoverage('a.dart', {1: 1, 2: 0})
      ..merge(FileCoverage('a.dart', {2: 4, 3: 0}));
    expect(file.hits, {1: 1, 2: 4, 3: 0});
    expect(file.linesHit, 2);
    expect(file.linesFound, 3);
  });

  test('totals and percent', () {
    final totals = CoverageTotals.of(parseLcov(sample));
    expect(totals.linesHit, 2);
    expect(totals.linesFound, 3);
    expect(totals.percent, closeTo(66.7, 0.1));
    expect(CoverageTotals.of(const []).percent, 100);
  });

  test('format writes sorted records with recomputed totals', () {
    final output = formatLcov([
      FileCoverage('b.dart', {2: 0, 1: 2}),
      FileCoverage('a.dart', {1: 1}),
    ]);
    expect(
      output,
      'SF:a.dart\nDA:1,1\nLF:1\nLH:1\nend_of_record\n'
      'SF:b.dart\nDA:1,2\nDA:2,0\nLF:2\nLH:1\nend_of_record\n',
    );
    expect(parseLcov(output).map((file) => file.path), ['a.dart', 'b.dart']);
  });
}
