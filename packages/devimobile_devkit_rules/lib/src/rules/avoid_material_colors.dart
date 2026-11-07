import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:devimobile_devkit_rules/src/elements.dart';

/// Reports the Material palette, such as `Colors.blue`.
///
/// `Colors.transparent` is allowed: it means "no color", like
/// `EdgeInsets.zero` means "no insets".
class AvoidMaterialColors extends AnalysisRule {
  /// Creates the rule.
  AvoidMaterialColors()
    : super(
        name: 'avoid_material_colors',
        description:
            'Colors come from the design system, not from the Material '
            'palette.',
      );

  /// The reported diagnostic.
  static const code = LintCode(
    'avoid_material_colors',
    "Color from the Material palette ('Colors.{0}').",
    correctionMessage: 'Try using a color from the design system.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Members of `Colors` that are allowed.
  static const allowed = {'transparent'};

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    final visitor = _Visitor(this);
    registry
      ..addPrefixedIdentifier(this, visitor)
      ..addPropertyAccess(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidMaterialColors rule;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) =>
      _check(node, node.identifier);

  @override
  void visitPropertyAccess(PropertyAccess node) =>
      _check(node, node.propertyName);

  void _check(Expression node, SimpleIdentifier member) {
    final type = declaringClass(member.element);
    if (type == null || type.name != 'Colors' || !isFromFlutter(type)) return;
    if (AvoidMaterialColors.allowed.contains(member.name)) return;
    // `/// Defaults to [Colors.blue].` is documentation, not a use.
    if (node.thisOrAncestorOfType<CommentReference>() != null) return;
    rule.reportAtNode(node, arguments: [member.name]);
  }
}
