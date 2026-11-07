import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/source/source.dart';
import 'package:analyzer/workspace/workspace.dart';
import 'package:devimobile_devkit_rules/src/scope.dart';
import 'package:test/test.dart';

void main() {
  late MemoryResourceProvider provider;

  File write(String path, String content) =>
      provider.getFile(path)..writeAsStringSync(content);

  setUp(() {
    provider = MemoryResourceProvider();
    write('/ws/analysis_options.yaml', '''
devimobile_devkit_rules:
  design_system_packages: [brand_ui]
''');
    write('/ws/packages/brand_ui/pubspec.yaml', 'name: brand_ui\n');
    write(
      '/ws/packages/brand_ui/analysis_options.yaml',
      'include: ../../analysis_options.yaml\n',
    );
    write('/ws/apps/mobile/pubspec.yaml', 'name: mobile\n');
  });

  RuleContext context(String filePath, {String? packageRoot}) =>
      _ParsedOnlyContext(
        write(filePath, ''),
        packageRoot == null ? null : provider.getFolder(packageRoot),
      );

  group('isChecked without a library element (parsed results)', () {
    test('skips a listed package through its include', () {
      final skipped = context(
        '/ws/packages/brand_ui/lib/src/tokens.dart',
        packageRoot: '/ws/packages/brand_ui',
      );
      expect(isChecked(skipped), isFalse);
    });

    test('checks another package', () {
      final checked = context(
        '/ws/apps/mobile/lib/main.dart',
        packageRoot: '/ws/apps/mobile',
      );
      expect(isChecked(checked), isTrue);
    });

    test('checks a file without a package or a package name', () {
      expect(isChecked(context('/loose/lib/a.dart')), isTrue);
      write('/ws/apps/unnamed/pubspec.yaml', 'description: no name\n');
      expect(
        isChecked(
          context(
            '/ws/apps/unnamed/lib/a.dart',
            packageRoot: '/ws/apps/unnamed',
          ),
        ),
        isTrue,
      );
    });
  });

  group('readOptionsFile', () {
    test('reads the key and the includes', () {
      final options = readOptionsFile(
        write('/x/analysis_options.yaml', '''
include: [a.yaml, package:p/b.yaml]
devimobile_devkit_rules:
  design_system_packages: ui
'''),
      );
      expect(options?.packages, {'ui'});
      expect(options?.includes, ['a.yaml', 'package:p/b.yaml']);
    });

    test('treats a file that disappears while read as missing', () {
      final file = write('/x/analysis_options.yaml', 'include: a.yaml\n');
      expect(readOptionsFile(_VanishingFile(file)), isNull);
    });
  });
}

/// A rule context in parsed-results mode: no library element.
class _ParsedOnlyContext implements RuleContext {
  _ParsedOnlyContext(this._file, this._packageRoot);

  final File _file;
  final Folder? _packageRoot;

  @override
  bool get isInLibDir => true;

  @override
  WorkspacePackage? get package => switch (_packageRoot) {
    final Folder root => _Package(root),
    null => null,
  };

  @override
  RuleContextUnit get definingUnit => RuleContextUnit(
    file: _file,
    content: '',
    diagnosticReporter: DiagnosticReporter(
      RecordingDiagnosticListener(),
      _UnusedSource(),
    ),
    unit: parseString(content: '').unit,
  );

  @override
  LibraryElement? get libraryElement =>
      throw UnsupportedError('Parsed results have no library element.');

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Package implements WorkspacePackage {
  _Package(this.root);

  @override
  final Folder root;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: avoid_implementing_value_types, a test double that is never compared.
class _UnusedSource implements Source {
  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A file that exists when asked, but is gone when read.
class _VanishingFile implements File {
  _VanishingFile(this._file);

  final File _file;

  @override
  bool get exists => true;

  @override
  String get path => _file.path;

  @override
  ResourceProvider get provider => _file.provider;

  @override
  int get modificationStamp => throw FileSystemException(path, 'Gone.');

  @override
  int get lengthSync => throw FileSystemException(path, 'Gone.');

  @override
  String readAsStringSync() => throw FileSystemException(path, 'Gone.');

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
