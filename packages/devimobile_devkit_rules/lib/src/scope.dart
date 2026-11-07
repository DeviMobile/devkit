import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:yaml/yaml.dart';

/// The top-level key of `analysis_options.yaml` that configures the rules.
const configKey = 'devimobile_devkit_rules';

/// The key under [configKey] that lists the design system packages.
const designSystemPackagesKey = 'design_system_packages';

/// The design system packages when nothing is configured.
const defaultDesignSystemPackages = {'design_system'};

/// Whether the rules check the library of [context]: it is in `lib/` and
/// not in a design system package, which may use raw values because it
/// defines the tokens.
bool isChecked(RuleContext context) {
  if (!context.isInLibDir) return false;
  final library = context.libraryElement;
  if (library == null) return true;
  final uri = library.uri;
  if (!uri.isScheme('package') || uri.pathSegments.isEmpty) return true;
  final optionsFile = library.session.analysisContext.contextRoot.optionsFile;
  return !_designSystemPackages(optionsFile).contains(uri.pathSegments.first);
}

/// Parsed configuration per options file, per resource provider.
final _cache = Expando<Map<String, ({int stamp, Set<String> packages})>>();

Set<String> _designSystemPackages(File? optionsFile) {
  if (optionsFile == null || !optionsFile.exists) {
    return defaultDesignSystemPackages;
  }
  final cache = _cache[optionsFile.provider] ??= {};
  final stamp = optionsFile.modificationStamp;
  final cached = cache[optionsFile.path];
  if (cached != null && cached.stamp == stamp) return cached.packages;
  final packages = parseDesignSystemPackages(optionsFile.readAsStringSync());
  cache[optionsFile.path] = (stamp: stamp, packages: packages);
  return packages;
}

/// The design system packages configured in the `analysis_options.yaml`
/// content [yaml]:
///
/// ```yaml
/// devimobile_devkit_rules:
///   design_system_packages: [design_system]
/// ```
///
/// A single name is accepted too. A missing or invalid value gives
/// [defaultDesignSystemPackages]; an empty list checks every package.
Set<String> parseDesignSystemPackages(String yaml) {
  final Object? document;
  try {
    document = loadYaml(yaml);
  } on YamlException {
    return defaultDesignSystemPackages;
  }
  if (document is! YamlMap) return defaultDesignSystemPackages;
  final section = document[configKey];
  if (section is! YamlMap) return defaultDesignSystemPackages;
  return switch (section[designSystemPackagesKey]) {
    final String name => {name},
    final YamlList names when names.every((name) => name is String) => {
      ...names.cast<String>(),
    },
    _ => defaultDesignSystemPackages,
  };
}
