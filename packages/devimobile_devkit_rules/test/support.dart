import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/package_config_file_builder.dart';
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
  const EdgeInsetsDirectional.fromSTEB(
    double start,
    double top,
    double end,
    double bottom,
  );
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
  ///
  /// The code under test lives in `lib/` of a package named [packageName].
  RuleTester(
    AbstractAnalysisRule Function() create, {
    String packageName = 'test',
  }) {
    setUp(() {
      _baseOptions = null;
      _harness = _Harness(create(), packageName)..setUp();
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

  String? _baseOptions;

  /// Sets [yaml] as the extra content of the test package's
  /// `analysis_options.yaml`, after what `analyzer_testing` writes there.
  void setAnalysisOptions(String yaml) {
    final path = _harness.convertPath(
      '${_harness.testPackageRootPath}/analysis_options.yaml',
    );
    final base = _baseOptions ??= _harness.getFile(path).readAsStringSync();
    _harness.newFile(path, '$base\n$yaml');
  }

  /// Like [setAnalysisOptions], but after an analysis: writes the file
  /// directly, as an editor would, without telling the analyzer, so only
  /// code that reads the file itself sees the change.
  void rewriteAnalysisOptions(String yaml) {
    final path = _harness.convertPath(
      '${_harness.testPackageRootPath}/analysis_options.yaml',
    );
    _harness.getFile(path).writeAsStringSync('$_baseOptions\n$yaml');
  }

  /// Writes [content] to [path], relative to the workspace root that
  /// contains the test package (`/home`).
  void writeWorkspaceFile(String path, String content) {
    _harness.newFile(
      _harness.convertPath('${_harness.workspaceRootPath}/$path'),
      content,
    );
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
  void addOtherPackageFile(String path, String code) =>
      writeOtherPackageFile(path, code);

  /// Writes [content] to [path] in the `other_ui` package.
  void writeOtherPackageFile(String path, String content) {
    _harness.newFile(_harness.convertPath('/package/other_ui/$path'), content);
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
  _Harness(AbstractAnalysisRule rule, this.packageName) {
    this.rule = rule;
  }

  /// The name of the package under test (`test` in `analyzer_testing`).
  final String packageName;

  @override
  void writeTestPackageConfig2({
    PackageConfigFileBuilder? config,
    String? languageVersion,
  }) {
    final copy = (config ?? PackageConfigFileBuilder()).copy()
      ..add(
        name: 'other_ui',
        rootFolder: getFolder(convertPath('/package/other_ui')),
      );
    writePackageConfig2(
      testPackageRootPath,
      config: copy,
      languageVersion: languageVersion,
      packageName: packageName,
    );
  }

  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    super.setUp();
    newPubspecYamlFile(testPackageRootPath, 'name: $packageName\n');
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
    // Redirecting factories of EdgeInsetsGeometry, as in Flutter; they make
    // `Padding(padding: .all(16))` resolve.
    _insert(
      '$flutterLib/src/painting/edge_insets.dart',
      after: '',
      text: "import 'package:flutter/src/devkit_extras.dart';\n",
    );
    _insert(
      '$flutterLib/src/painting/edge_insets.dart',
      after: 'const EdgeInsetsGeometry();',
      text: '''
  static const EdgeInsetsGeometry zero = EdgeInsets.zero;
  const factory EdgeInsetsGeometry.all(double value) = EdgeInsets.all;
  const factory EdgeInsetsGeometry.only({
    double left,
    double right,
    double top,
    double bottom,
  }) = EdgeInsets.only;
  const factory EdgeInsetsGeometry.directional({
    double start,
    double end,
    double top,
    double bottom,
  }) = EdgeInsetsDirectional.only;
  const factory EdgeInsetsGeometry.symmetric({
    double vertical,
    double horizontal,
  }) = EdgeInsets.symmetric;
  const factory EdgeInsetsGeometry.fromLTRB(
    double left,
    double top,
    double right,
    double bottom,
  ) = EdgeInsets.fromLTRB;
  factory EdgeInsetsGeometry.fromViewPadding(
    Object padding,
    double devicePixelRatio,
  ) = EdgeInsets.fromViewPadding;
  const factory EdgeInsetsGeometry.fromSTEB(
    double start,
    double top,
    double end,
    double bottom,
  ) = EdgeInsetsDirectional.fromSTEB;''',
    );
    _insert(
      '$flutterLib/src/painting/edge_insets.dart',
      after: 'static const EdgeInsets zero = EdgeInsets.only();',
      text: '''
  EdgeInsets.fromViewPadding(Object padding, double devicePixelRatio)
    : left = 0,
      top = 0,
      right = 0,
      bottom = 0;
  factory EdgeInsets.fromWindowPadding(
    Object padding,
    double devicePixelRatio,
  ) = EdgeInsets.fromViewPadding;''',
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
