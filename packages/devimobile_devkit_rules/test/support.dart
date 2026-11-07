import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';

/// Flutter APIs that the mock Flutter package of `analyzer_testing` lacks.
const _flutterExtras = '''
import 'package:flutter/widgets.dart';

class EdgeInsetsDirectional extends EdgeInsetsGeometry {
  static const EdgeInsetsDirectional zero = EdgeInsetsDirectional.only();
  const EdgeInsetsDirectional.only({
    double start = 0.0,
    double top = 0.0,
    double end = 0.0,
    double bottom = 0.0,
  });
}

class IconButton extends StatelessWidget {
  const IconButton({super.key, required Widget icon, String? tooltip});
}

class Tooltip extends StatelessWidget {
  const Tooltip({super.key, String? message, Widget? child});
}

class InputDecoration {
  const InputDecoration({String? hintText, String? labelText, String? helperText});
}
''';

/// Runs an analysis rule on Dart code in a fresh in-memory package with a
/// mock Flutter SDK; one instance per test, created in `setUp`.
class RuleTester {
  /// Registers `setUp` and `tearDown` that create the rule with [create].
  RuleTester(AbstractAnalysisRule Function() create) {
    setUp(() {
      _harness = _Harness(create())..setUp();
    });
    tearDown(() => _harness.tearDown());
  }

  late _Harness _harness;

  /// The resolved test file of the last analysis.
  ResolvedUnitResult get result => _harness.result;

  /// Expects the rule to report exactly at [snippets] in [code], in order;
  /// a repeated snippet matches its next occurrence.
  Future<void> expectLints(
    String code,
    List<String> snippets, {
    List<Pattern> messageContainsAll = const [],
  }) {
    var from = 0;
    final ranges = <(int, int)>[];
    for (final snippet in snippets) {
      final offset = code.indexOf(snippet, from);
      if (offset < 0) throw ArgumentError('Snippet not found: $snippet');
      ranges.add((offset, snippet.length));
      from = offset + 1;
    }
    final expected = [
      for (final (offset, length) in ranges)
        _harness.lint(offset, length, messageContainsAll: messageContainsAll),
    ];
    return _harness.assertDiagnostics(code, expected);
  }

  /// Expects no diagnostics in [code].
  Future<void> expectNone(String code) => _harness.assertNoDiagnostics(code);

  /// Expects no diagnostics in [code] written at [path], relative to the
  /// test package root.
  Future<void> expectNoneAt(String path, String code) {
    final file = _harness.convertPath('${_harness.testPackageRootPath}/$path');
    _harness.newFile(file, code);
    return _harness.assertNoDiagnosticsInFile(file);
  }

  /// Adds a library at `package:other_ui/[path]`, a package that is not
  /// Flutter.
  void addOtherPackageFile(String path, String code) {
    _harness.newFile(_harness.convertPath('/package/other_ui/$path'), code);
  }

  /// Applies the fix created by [create] to the first diagnostic in [code].
  ///
  /// Returns `null` when the fix offers no change.
  Future<String?> applyFix(
    String code,
    CorrectionProducer Function(CorrectionProducerContext) create,
  ) async {
    _harness.newFile(_harness.testFilePath, code);
    final unit = await _harness.resolveFile(_harness.testFilePath);
    final codes = _harness.rule.diagnosticCodes;
    final diagnostic = unit.diagnostics.firstWhere(
      (diagnostic) => codes.contains(diagnostic.diagnosticCode),
    );
    final library = await unit.session.getResolvedLibrary(
      unit.path,
    ) as ResolvedLibraryResult;
    final producer = create(
      CorrectionProducerContext.createResolved(
        libraryResult: library,
        unitResult: unit,
        diagnostic: diagnostic,
        selectionOffset: diagnostic.offset,
        selectionLength: diagnostic.length,
      ),
    );
    final builder = ChangeBuilder(session: unit.session);
    await producer.compute(builder);
    final edits = builder.sourceChange.edits;
    if (edits.isEmpty) return null;
    return SourceEdit.applySequence(code, edits.single.edits);
  }
}

class _Harness extends AnalysisRuleTest {
  _Harness(AbstractAnalysisRule rule) {
    this.rule = rule;
  }

  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    newPackage('other_ui');
    super.setUp();
    final flutterLib = '$packagesRootPath/flutter/lib';
    newFile('$flutterLib/src/devkit_extras.dart', _flutterExtras);
    _insert(
      '$flutterLib/src/material/colors.dart',
      after: 'abstract final class Colors {',
      text: '\n  static const Color transparent = Color(0x00000000);',
    );
    _insert(
      '$flutterLib/src/widgets/basic.dart',
      after:
          'const SizedBox({super.key, this.width, this.height, super.child});',
      text:
          '\n  const SizedBox.square({super.key, super.child, '
          'double? dimension}) : width = dimension, height = dimension;',
    );
    _insert(
      '$flutterLib/material.dart',
      after: "export 'widgets.dart';\n",
      text: "export 'src/devkit_extras.dart';\n",
    );
  }

  void _insert(String path, {required String after, required String text}) {
    final file = getFile(convertPath(path));
    final content = file.readAsStringSync();
    final index = content.indexOf(after);
    if (index < 0) {
      throw StateError('Mock Flutter changed: "$after" not found in $path');
    }
    final at = index + after.length;
    newFile(path, content.replaceRange(at, at, text));
  }
}
