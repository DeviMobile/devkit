import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:devimobile_devkit_rules/src/elements.dart';
import 'package:devimobile_devkit_rules/src/rules/numeric_argument_rule.dart';

/// Reports `Color` built from numeric literals, such as `Color(0xFF2196F3)`.
class AvoidColorLiterals extends NumericArgumentRule {
  /// Creates the rule.
  AvoidColorLiterals()
    : super(
        name: 'avoid_color_literals',
        description:
            'Colors come from the design system, not from numeric literals.',
      );

  /// The reported diagnostic.
  static const code = LintCode(
    'avoid_color_literals',
    'Color built from a numeric literal.',
    correctionMessage: 'Try using a color from the design system.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  bool appliesTo(
    ConstructorElement constructor,
    FormalParameterElement parameter,
  ) {
    final type = constructor.enclosingElement;
    return type.name == 'Color' && isFromDartUi(type);
  }
}
