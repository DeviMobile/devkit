import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';

/// Whether [element] is declared in the Flutter framework (`package:flutter`).
bool isFromFlutter(Element? element) {
  final uri = element?.library?.uri;
  return uri != null &&
      uri.isScheme('package') &&
      uri.pathSegments.isNotEmpty &&
      uri.pathSegments.first == 'flutter';
}

/// Whether [element] is declared in `dart:ui`, where Flutter's `Color` lives.
bool isFromDartUi(Element? element) =>
    element?.library?.uri.toString() == 'dart:ui';

/// The class that declares [element], when it is a class member.
InterfaceElement? declaringClass(Element? element) {
  final enclosing = element?.enclosingElement;
  return enclosing is InterfaceElement ? enclosing : null;
}

/// The argument of an invocation that contains [expression], walking up
/// through the wrappers accepted by [isWrapper].
///
/// Returns `null` when [expression] is not (part of) an argument.
({Argument argument, Expression value})? enclosingArgument(
  Expression expression, {
  required bool Function(AstNode parent, AstNode child) isWrapper,
}) {
  AstNode value = expression;
  var parent = value.parent;
  while (parent != null && isWrapper(parent, value)) {
    value = parent;
    parent = value.parent;
  }
  if (value is! Expression) return null;
  return switch (parent) {
    NamedArgument() => (argument: parent, value: value),
    ArgumentList() => (argument: value, value: value),
    _ => null,
  };
}

/// The constructor that [constructor] redirects to, followed to the end.
ConstructorElement redirectTarget(ConstructorElement constructor) {
  var target = constructor;
  final seen = <ConstructorElement>{};
  while (seen.add(target)) {
    final next = target.redirectedConstructor?.baseElement;
    if (next == null) break;
    target = next;
  }
  return target;
}

/// The parameter that receives [argument], following `super.x` parameters
/// to the constructor that declares them.
FormalParameterElement? receivingParameter(Argument argument) {
  var parameter = argument.correspondingParameter;
  while (parameter is SuperFormalParameterElement) {
    final next = parameter.superConstructorParameter;
    if (next == null) break;
    parameter = next;
  }
  return parameter;
}

/// The value expression of [argument].
Expression argumentValue(Argument argument) => argument.argumentExpression;

const Set<TokenType> _arithmetic = {
  TokenType.PLUS,
  TokenType.MINUS,
  TokenType.STAR,
  TokenType.SLASH,
  TokenType.TILDE_SLASH,
  TokenType.PERCENT,
};

/// Whether [expression] is built only from numeric literals, such as `16`,
/// `-8.0`, `(4)` or `8 * 2`.
bool isNumericLiteralExpression(Expression expression) => switch (expression) {
  IntegerLiteral() || DoubleLiteral() => true,
  ParenthesizedExpression(:final expression) => isNumericLiteralExpression(
    expression,
  ),
  PrefixExpression(:final operator, :final operand) =>
    operator.type == TokenType.MINUS && isNumericLiteralExpression(operand),
  BinaryExpression(:final operator, :final leftOperand, :final rightOperand) =>
    _arithmetic.contains(operator.type) &&
        isNumericLiteralExpression(leftOperand) &&
        isNumericLiteralExpression(rightOperand),
  _ => false,
};

/// Whether some value that [expression] can take is a numeric literal
/// expression: directly, or as a branch of `?:`, `??` or a `switch`.
bool hasNumericLiteralOutcome(Expression expression) => switch (expression) {
  ParenthesizedExpression(:final expression) => hasNumericLiteralOutcome(
    expression,
  ),
  ConditionalExpression(:final thenExpression, :final elseExpression) =>
    hasNumericLiteralOutcome(thenExpression) ||
        hasNumericLiteralOutcome(elseExpression),
  BinaryExpression(:final operator, :final leftOperand, :final rightOperand)
      when operator.type == TokenType.QUESTION_QUESTION =>
    hasNumericLiteralOutcome(leftOperand) ||
        hasNumericLiteralOutcome(rightOperand),
  SwitchExpression(:final cases) => cases.any(
    (switchCase) => hasNumericLiteralOutcome(switchCase.expression),
  ),
  _ => isNumericLiteralExpression(expression),
};

/// The value of a numeric literal expression (see
/// [isNumericLiteralExpression]), or `null` for anything else and for
/// integer division by zero.
num? numericValue(Expression expression) {
  switch (expression) {
    case IntegerLiteral(:final value):
      return value;
    case DoubleLiteral(:final value):
      return value;
    case ParenthesizedExpression(:final expression):
      return numericValue(expression);
    case PrefixExpression(:final operator, :final operand)
        when operator.type == TokenType.MINUS:
      final value = numericValue(operand);
      return value == null ? null : -value;
    case BinaryExpression(
      :final operator,
      :final leftOperand,
      :final rightOperand,
    ):
      final left = numericValue(leftOperand);
      final right = numericValue(rightOperand);
      if (left == null || right == null) return null;
      return switch (operator.type) {
        TokenType.PLUS => left + right,
        TokenType.MINUS => left - right,
        TokenType.STAR => left * right,
        TokenType.SLASH => left / right,
        TokenType.TILDE_SLASH when right != 0 => left ~/ right,
        TokenType.PERCENT when right != 0 => left % right,
        _ => null,
      };
    default:
      return null;
  }
}

/// Whether a string [child] can end up as the value of [parent]:
/// parentheses, a branch of `?:`, `??` or a `switch` expression, or an
/// operand of `+`.
bool isStringWrapper(AstNode parent, AstNode child) => switch (parent) {
  ParenthesizedExpression() => true,
  ConditionalExpression(:final condition) => child != condition,
  BinaryExpression(:final operator) =>
    operator.type == TokenType.QUESTION_QUESTION ||
        operator.type == TokenType.PLUS,
  SwitchExpressionCase(:final expression) => identical(child, expression),
  SwitchExpression() => child is SwitchExpressionCase,
  _ => false,
};

final _letter = RegExp(r'\p{L}', unicode: true);

/// Whether the literal parts of [literal] contain a letter in any script.
///
/// Interpolated expressions are not literal text, so `'$count'` and
/// `'$done / $total'` have no letters, while `'Hello $name'` has.
bool hasLetters(StringLiteral literal) => switch (literal) {
  SimpleStringLiteral(:final value) => _letter.hasMatch(value),
  AdjacentStrings(:final strings) => strings.any(hasLetters),
  StringInterpolation(:final elements) => elements.any(
    (element) =>
        element is InterpolationString && _letter.hasMatch(element.value),
  ),
};
