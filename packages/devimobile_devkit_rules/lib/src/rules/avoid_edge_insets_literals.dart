import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:devimobile_devkit_rules/src/elements.dart';
import 'package:devimobile_devkit_rules/src/rules/numeric_argument_rule.dart';

/// Reports `EdgeInsets` and `EdgeInsetsDirectional` built from numeric
/// literals, such as `EdgeInsets.all(16)`.
class AvoidEdgeInsetsLiterals extends NumericArgumentRule {
  /// Creates the rule.
  AvoidEdgeInsetsLiterals()
    : super(
        name: 'avoid_edge_insets_literals',
        description:
            'Insets come from the spacing tokens of the design system, not '
            'from numeric literals.',
      );

  /// The reported diagnostic.
  static const code = LintCode(
    'avoid_edge_insets_literals',
    'Insets built from a numeric literal.',
    correctionMessage:
        'Try using spacing from the design system, or EdgeInsets.zero.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// The classes the rule checks.
  static const classNames = {'EdgeInsets', 'EdgeInsetsDirectional'};

  @override
  LintCode get diagnosticCode => code;

  @override
  bool appliesTo(ConstructorElement constructor) {
    final type = constructor.enclosingElement;
    return classNames.contains(type.name) && isFromFlutter(type);
  }
}
