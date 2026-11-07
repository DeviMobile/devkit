import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:devimobile_devkit_rules/src/elements.dart';
import 'package:devimobile_devkit_rules/src/rules/numeric_argument_rule.dart';

/// Reports `SizedBox` sized by numeric literals, such as
/// `SizedBox(height: 8)`.
class AvoidSizedBoxLiterals extends NumericArgumentRule {
  /// Creates the rule.
  AvoidSizedBoxLiterals()
    : super(
        name: 'avoid_sized_box_literals',
        description:
            'Gaps and sizes come from the design system, not from numeric '
            'literals.',
      );

  /// The reported diagnostic.
  static const code = LintCode(
    'avoid_sized_box_literals',
    'SizedBox sized by a numeric literal.',
    correctionMessage:
        'Try using spacing from the design system, or SizedBox.shrink().',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  bool appliesTo(ConstructorElement constructor) {
    final type = constructor.enclosingElement;
    return type.name == 'SizedBox' && isFromFlutter(type);
  }
}
