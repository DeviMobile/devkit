/// Formats rows as a plain-text table with padded columns.
///
/// Columns listed in [rightAligned] (by index) are padded on the left, which
/// suits numbers.
String formatTable(
  List<String> header,
  List<List<String>> rows, {
  Set<int> rightAligned = const {},
}) {
  final all = [header, ...rows];
  final widths = [
    for (var column = 0; column < header.length; column++)
      all
          .map((row) => column < row.length ? row[column].length : 0)
          .reduce((a, b) => a > b ? a : b),
  ];
  String cell(List<String> row, int column) {
    final text = column < row.length ? row[column] : '';
    return rightAligned.contains(column)
        ? text.padLeft(widths[column])
        : text.padRight(widths[column]);
  }

  String format(List<String> row) =>
      [for (var column = 0; column < header.length; column++) cell(row, column)]
          .join('  ')
          .trimRight();

  return [
    format(header),
    widths.map((width) => '-' * width).join('  '),
    ...rows.map(format),
  ].join('\n');
}
