import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:yaml/yaml.dart';

/// The top-level key of `analysis_options.yaml` that configures the rules.
const configKey = 'devimobile_devkit_rules';

/// The key under [configKey] that lists the design system packages.
const designSystemPackagesKey = 'design_system_packages';

/// The design system packages when nothing is configured.
const defaultDesignSystemPackages = {'design_system'};

const _optionsFileName = 'analysis_options.yaml';

/// Whether the rules check the library of [context]: it is in `lib/` and
/// not in a design system package, which may use raw values because it
/// defines the tokens.
///
/// Computed once per library and shared by all rules.
bool isChecked(RuleContext context) {
  if (!context.isInLibDir) return false;
  return _checked[context] ??= _isChecked(context);
}

final _checked = Expando<bool>();

bool _isChecked(RuleContext context) {
  final root = context.package?.root;
  if (root == null) return true;
  final name = _packageName(root.getFile('pubspec.yaml'));
  if (name == null) return true;
  final unit = context.definingUnit;
  // Resolved results give a session for `package:` includes; parsed results
  // (no library element) skip those includes.
  final session = unit.unit.declaredFragment?.element.session;
  return !designSystemPackagesFor(unit.file, session: session).contains(name);
}

/// The design system packages for [file], from the `analysis_options.yaml`
/// that applies to it (the nearest one in its folder or above) and the files
/// it includes.
///
/// The including file wins over the files it includes, and a later entry of
/// an `include:` list wins over an earlier one, as in the analyzer. Without
/// the key, or with an invalid value, the result is
/// [defaultDesignSystemPackages]. `package:` includes are resolved through
/// [session] when given.
Set<String> designSystemPackagesFor(File file, {AnalysisSession? session}) {
  var folder = file.parent;
  while (true) {
    final options = folder.getFile(_optionsFileName);
    if (options.exists) {
      return _lookUp(options, session, {}) ?? defaultDesignSystemPackages;
    }
    if (folder.isRoot) return defaultDesignSystemPackages;
    folder = folder.parent;
  }
}

Set<String>? _lookUp(File file, AnalysisSession? session, Set<String> seen) {
  if (!seen.add(file.path)) return null;
  final options = readOptionsFile(file);
  if (options == null) return null;
  if (options.packages case final packages?) return packages;
  for (final include in options.includes.reversed) {
    final included = _resolveInclude(file, include, session);
    if (included == null) continue;
    if (_lookUp(included, session, seen) case final packages?) {
      return packages;
    }
  }
  return null;
}

File? _resolveInclude(File from, String include, AnalysisSession? session) {
  final provider = from.provider;
  final String? path;
  if (include.startsWith('package:')) {
    final uri = Uri.tryParse(include);
    path = uri == null ? null : session?.uriConverter.uriToPath(uri);
  } else {
    final context = provider.pathContext;
    path = context.normalize(context.join(from.parent.path, include));
  }
  return path == null ? null : provider.getFile(path);
}

/// What one `analysis_options.yaml` says: the design system packages under
/// [configKey] (`null` when the key is absent) and its `include:` entries.
typedef OptionsFile = ({Set<String>? packages, List<String> includes});

/// Reads [file], or returns `null` when it is missing or unreadable.
///
/// Cached per file until its modification stamp or length changes.
OptionsFile? readOptionsFile(File file) {
  try {
    if (!file.exists) return null;
    final stamp = (file.modificationStamp, file.lengthSync);
    final cache = _optionsCache[file.provider] ??= {};
    final cached = cache[file.path];
    if (cached != null && cached.stamp == stamp) return cached.options;
    final options = parseOptionsFile(file.readAsStringSync());
    cache[file.path] = (stamp: stamp, options: options);
    return options;
  } on FileSystemException {
    return null;
  }
}

final _optionsCache =
    Expando<Map<String, ({(int, int) stamp, OptionsFile options})>>();

/// Parses the content [yaml] of an `analysis_options.yaml`:
///
/// ```yaml
/// include: package:devimobile_devkit_lints/strict.yaml
/// devimobile_devkit_rules:
///   design_system_packages: [design_system]
/// ```
///
/// `design_system_packages` takes a name or a list of names; an invalid value
/// gives [defaultDesignSystemPackages].
OptionsFile parseOptionsFile(String yaml) {
  final Object? document;
  try {
    document = loadYaml(yaml);
  } on YamlException {
    return (packages: null, includes: const []);
  }
  if (document is! YamlMap) return (packages: null, includes: const []);
  final includes = switch (document['include']) {
    final String include => [include],
    final YamlList list => [...list.whereType<String>()],
    _ => const <String>[],
  };
  final section = document[configKey];
  final Set<String>? packages = switch (section) {
    null => null,
    YamlMap() when !section.containsKey(designSystemPackagesKey) => null,
    YamlMap() => switch (section[designSystemPackagesKey]) {
      final String name => {name},
      final YamlList names when names.every((name) => name is String) => {
        ...names.cast<String>(),
      },
      _ => defaultDesignSystemPackages,
    },
    _ => defaultDesignSystemPackages,
  };
  return (packages: packages, includes: includes);
}

/// The design system packages of one file without includes; see
/// [parseOptionsFile].
Set<String> parseDesignSystemPackages(String yaml) =>
    parseOptionsFile(yaml).packages ?? defaultDesignSystemPackages;

String? _packageName(File pubspec) {
  try {
    if (!pubspec.exists) return null;
    final stamp = (pubspec.modificationStamp, pubspec.lengthSync);
    final cache = _nameCache[pubspec.provider] ??= {};
    final cached = cache[pubspec.path];
    if (cached != null && cached.stamp == stamp) return cached.name;
    final document = loadYaml(pubspec.readAsStringSync());
    final name = document is YamlMap ? document['name'] : null;
    final result = name is String ? name : null;
    cache[pubspec.path] = (stamp: stamp, name: result);
    return result;
  } on FileSystemException {
    return null;
  } on YamlException {
    return null;
  }
}

final _nameCache = Expando<Map<String, ({(int, int) stamp, String? name})>>();
