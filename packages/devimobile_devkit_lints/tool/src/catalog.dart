import 'dart:convert';

import 'package:yaml/yaml.dart';

/// Where a rule is enabled.
enum Level {
  /// Enabled in `core.yaml` (and therefore in `strict.yaml`).
  core,

  /// Enabled only in `strict.yaml`.
  strict,

  /// Not enabled.
  off,
}

/// A lint rule as described by the Dart SDK machine-readable catalog.
final class SdkRule {
  const SdkRule({
    required this.name,
    required this.state,
    required this.sinceDartSdk,
    required this.fixStatus,
    required this.incompatible,
    required this.description,
  });

  factory SdkRule.fromJson(Map<String, Object?> json) => SdkRule(
    name: json['name']! as String,
    state: json['state']! as String,
    sinceDartSdk: json['sinceDartSdk']! as String,
    fixStatus: json['fixStatus']! as String,
    incompatible: List<String>.unmodifiable(
      (json['incompatible']! as List<Object?>).cast<String>(),
    ),
    description: json['description']! as String,
  );

  final String name;

  /// `stable`, `experimental`, `deprecated` or `removed`.
  final String state;
  final String sinceDartSdk;

  /// `hasFix`, `needsFix`, `noFix` or `needsEvaluation`.
  final String fixStatus;
  final List<String> incompatible;
  final String description;

  bool get isRemoved => state == 'removed';
  bool get hasFix => fixStatus == 'hasFix';

  Map<String, Object?> toJson() => {
    'name': name,
    'state': state,
    'sinceDartSdk': sinceDartSdk,
    'fixStatus': fixStatus,
    'incompatible': incompatible,
    'description': description,
  };
}

/// Snapshot of the lint rule catalog of one Dart SDK version.
final class SdkCatalog {
  const SdkCatalog({
    required this.sdk,
    required this.source,
    required this.rules,
  });

  factory SdkCatalog.parse(String json) {
    final root = jsonDecode(json) as Map<String, Object?>;
    final rules = (root['rules']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(SdkRule.fromJson)
        .toList();
    return SdkCatalog(
      sdk: root['sdk']! as String,
      source: root['source']! as String,
      rules: rules,
    );
  }

  /// URL of the machine-readable catalog for a given SDK tag.
  static String sourceUrl(String sdk) =>
      'https://raw.githubusercontent.com/dart-lang/sdk/$sdk/pkg/linter/tool/machine/rules.json';

  final String sdk;
  final String source;
  final List<SdkRule> rules;

  Iterable<SdkRule> get activeRules => rules.where((rule) => !rule.isRemoved);

  String toJsonString() {
    final sorted = [...rules]..sort((a, b) => a.name.compareTo(b.name));
    const encoder = JsonEncoder.withIndent('  ');
    final body = encoder.convert({
      'sdk': sdk,
      'source': source,
      'rules': [for (final rule in sorted) rule.toJson()],
    });
    return '$body\n';
  }
}

/// Our decision about one SDK rule.
final class Decision {
  const Decision({
    required this.name,
    required this.level,
    required this.reason,
  });

  final String name;
  final Level level;
  final String reason;

  bool get isEnabled => level != Level.off;
}

/// Parses `tool/decisions.yaml`.
Map<String, Decision> parseDecisions(String source) {
  final document = loadYaml(source);
  if (document is! YamlMap) {
    throw const FormatException('decisions.yaml must be a map of rule names');
  }
  final levels = Level.values.asNameMap();
  final decisions = <String, Decision>{};
  for (final MapEntry(:key, :value) in document.entries) {
    if (key is! String || value is! YamlMap) {
      throw FormatException('Entry "$key" must be a map with level and reason');
    }
    final level = levels[value['level']];
    final reason = value['reason'];
    if (level == null || reason is! String) {
      throw FormatException(
        'Entry "$key" needs level (core, strict or off) and a reason',
      );
    }
    decisions[key] = Decision(name: key, level: level, reason: reason);
  }
  return decisions;
}

/// Returns every problem that blocks generating the rule sets.
List<String> validate(SdkCatalog catalog, Map<String, Decision> decisions) {
  final problems = <String>[];
  final known = {for (final rule in catalog.rules) rule.name: rule};

  for (final rule in catalog.activeRules) {
    if (!decisions.containsKey(rule.name)) {
      problems.add(
        '${rule.name}: no decision for this SDK ${catalog.sdk} rule '
        '(${rule.state}); add it to tool/decisions.yaml',
      );
    }
  }

  for (final decision in decisions.values) {
    final rule = known[decision.name];
    if (rule == null) {
      problems.add(
        '${decision.name}: not in the SDK ${catalog.sdk} catalog; '
        'remove the decision',
      );
    } else if (rule.isRemoved) {
      problems.add(
        '${decision.name}: removed from the SDK; remove the decision',
      );
    } else if (decision.isEnabled && rule.state != 'stable') {
      problems.add(
        '${decision.name}: ${rule.state} rules must stay off',
      );
    }
    if (decision.reason.trim().isEmpty) {
      problems.add('${decision.name}: empty reason');
    }
  }

  // core.yaml is a subset of strict.yaml, so checking strict covers both.
  final enabled = {
    for (final decision in decisions.values)
      if (decision.isEnabled) decision.name,
  };
  for (final name in enabled.toList()..sort()) {
    for (final other in known[name]?.incompatible ?? const <String>[]) {
      if (enabled.contains(other) && name.compareTo(other) < 0) {
        problems.add('$name and $other are incompatible but both enabled');
      }
    }
  }
  return problems;
}

/// The lowest Dart SDK that knows every enabled rule.
String minimumSdk(SdkCatalog catalog, Map<String, Decision> decisions) {
  var minimum = '2.0';
  for (final rule in catalog.activeRules) {
    final decision = decisions[rule.name];
    if (decision != null &&
        decision.isEnabled &&
        compareVersions(rule.sinceDartSdk, minimum) > 0) {
      minimum = rule.sinceDartSdk;
    }
  }
  return minimum;
}

/// Compares dotted numeric versions such as `3.13` and `3.9.1`.
int compareVersions(String a, String b) {
  final left = a.split('.').map(int.parse).toList();
  final right = b.split('.').map(int.parse).toList();
  for (var i = 0; i < left.length || i < right.length; i++) {
    final x = i < left.length ? left[i] : 0;
    final y = i < right.length ? right[i] : 0;
    if (x != y) {
      return x.compareTo(y);
    }
  }
  return 0;
}

const _generatedHeader =
    '# GENERATED by tool/generate.dart from tool/decisions.yaml. Do not edit.\n'
    '# Every decision with its reason: RULES.md\n';

/// Renders the generated files, keyed by path relative to the package root.
Map<String, String> renderOutputs(
  SdkCatalog catalog,
  Map<String, Decision> decisions,
) {
  List<String> namesAt(Level level) => [
    for (final decision in decisions.values)
      if (decision.level == level) decision.name,
  ]..sort();

  String ruleList(List<String> names) =>
      names.map((name) => '    - $name\n').join();

  final core = StringBuffer()
    ..write(_generatedHeader)
    ..write('\n')
    ..write('analyzer:\n')
    ..write('  language:\n')
    ..write('    strict-inference: true\n')
    ..write('\n')
    ..write('linter:\n')
    ..write('  rules:\n')
    ..write(ruleList(namesAt(Level.core)));

  final strict = StringBuffer()
    ..write(_generatedHeader)
    ..write('\n')
    ..write('include: package:devimobile_devkit_lints/core.yaml\n')
    ..write('\n')
    ..write('linter:\n')
    ..write('  rules:\n')
    ..write(ruleList(namesAt(Level.strict)));

  return {
    'lib/core.yaml': core.toString(),
    'lib/strict.yaml': strict.toString(),
    'RULES.md': _renderRulesMarkdown(catalog, decisions),
  };
}

String _renderRulesMarkdown(
  SdkCatalog catalog,
  Map<String, Decision> decisions,
) {
  final rules = catalog.activeRules.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  int count(Level level) =>
      decisions.values.where((decision) => decision.level == level).length;
  final removed = catalog.rules.length - rules.length;

  final out = StringBuffer()
    ..writeln('# Rules')
    ..writeln()
    ..writeln(
      '<!-- GENERATED by tool/generate.dart from tool/decisions.yaml. '
      'Do not edit. -->',
    )
    ..writeln()
    ..writeln(
      'A decision for every lint rule of Dart SDK ${catalog.sdk} '
      '(${rules.length} rules; $removed removed rules are not listed). '
      'Source: [SDK catalog](${catalog.source}).',
    )
    ..writeln()
    ..writeln('- `core`: ${count(Level.core)} rules (`core.yaml`)')
    ..writeln(
      '- `strict`: ${count(Level.strict)} more rules '
      '(`strict.yaml` = `core` + these)',
    )
    ..writeln('- `off`: ${count(Level.off)} rules')
    ..writeln()
    ..writeln(
      'The `dart fix` column says whether `dart fix --apply` can fix '
      'the rule automatically.',
    )
    ..writeln()
    ..writeln('| Rule | Level | `dart fix` | Reason |')
    ..writeln('|---|---|---|---|');
  for (final rule in rules) {
    final decision = decisions[rule.name];
    final level = decision?.level.name ?? '—';
    final state = rule.state == 'stable' ? '' : ' (${rule.state})';
    final reason = (decision?.reason ?? '').replaceAll('|', r'\|');
    out.writeln(
      '| [`${rule.name}`](https://dart.dev/tools/linter-rules/${rule.name})'
      '$state | $level | ${rule.hasFix ? 'yes' : 'no'} | $reason |',
    );
  }
  return out.toString();
}
