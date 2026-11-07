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

  /// Whether the rule applies to invocations of [constructor].
  bool appliesTo(ConstructorElement constructor);

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    final visitor = _Visitor(this);
    registry
      ..addIntegerLiteral(this, visitor)
      ..addDoubleLiteral(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final NumericArgumentRule rule;

  @override
  void visitDoubleLiteral(DoubleLiteral node) => _check(node);

  @override
  void visitIntegerLiteral(IntegerLiteral node) => _check(node);

  void _check(Literal literal) {
    final found = enclosingArgument(literal, isWrapper: isNumericWrapper);
    if (found == null) return;
    final value = found.value;
    // `spacing * 2` is a computed value, not a literal.
    if (!isNumericLiteralExpression(value)) return;
    // Report once per invocation: from the first literal of the first
    // literal argument.
    if (!identical(_firstLiteral(value), literal)) return;
    final arguments = found.argument.parent;
    if (arguments is! ArgumentList) return;
    final firstLiteralArgument = arguments.arguments
        .map(argumentValue)
        .firstWhere(isNumericLiteralExpression);
    if (!identical(firstLiteralArgument, value)) return;

    final constructor = receivingParameter(found.argument)?.enclosingElement;
    if (constructor is! ConstructorElement || !rule.appliesTo(constructor)) {
      return;
    }
    rule.reportAtNode(arguments.parent);
  }

  static Expression _firstLiteral(Expression expression) =>
      switch (expression) {
        ParenthesizedExpression(:final expression) => _firstLiteral(expression),
        PrefixExpression(:final operand) => _firstLiteral(operand),
        BinaryExpression(:final leftOperand) => _firstLiteral(leftOperand),
        _ => expression,
      };
}
