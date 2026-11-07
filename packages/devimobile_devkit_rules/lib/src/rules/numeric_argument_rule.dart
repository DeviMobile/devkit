import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:devimobile_devkit_rules/src/elements.dart';

/// A rule that reports constructor invocations of selected classes with a
/// numeric literal argument, once per invocation.
abstract class NumericArgumentRule extends AnalysisRule {
  /// Creates a rule with the given [name] and [description].
  NumericArgumentRule({required super.name, required super.description});

  /// Whether the rule checks [parameter] of [constructor].
  ///
  /// [constructor] is the end of any chain of redirecting factories, so
  /// `EdgeInsetsGeometry.all` arrives as `EdgeInsets.all`; [parameter] is the
  /// parameter of the invoked constructor.
  bool appliesTo(
    ConstructorElement constructor,
    FormalParameterElement parameter,
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    registry.addArgumentList(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final NumericArgumentRule rule;

  @override
  void visitArgumentList(ArgumentList node) {
    for (final argument in node.arguments) {
      final parameter = receivingParameter(argument);
      final constructor = parameter?.enclosingElement;
      if (parameter == null || constructor is! ConstructorElement) continue;
      if (!rule.appliesTo(redirectTarget(constructor), parameter)) continue;
      if (hasNumericLiteralOutcome(argumentValue(argument))) {
        rule.reportAtNode(node.parent);
        return;
      }
    }
  }
}
