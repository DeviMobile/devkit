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

/// Whether [parent] only wraps a numeric [child] without adding a name:
/// parentheses, a unary minus or arithmetic.
bool isNumericWrapper(AstNode parent, AstNode child) => switch (parent) {
  ParenthesizedExpression() => true,
  PrefixExpression(:final operator) => operator.type == TokenType.MINUS,
  BinaryExpression(:final operator) => _arithmetic.contains(operator.type),
  _ => false,
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

/// The numeric value of a literal, possibly in parentheses or negated.
///
/// Returns `null` for anything else, including arithmetic.
num? numericLiteralValue(Expression expression) => switch (expression) {
  IntegerLiteral(:final value) => value,
  DoubleLiteral(:final value) => value,
  ParenthesizedExpression(:final expression) => numericLiteralValue(expression),
  PrefixExpression(:final operator, :final operand)
      when operator.type == TokenType.MINUS =>
    switch (numericLiteralValue(operand)) {
      final num value => -value,
      null => null,
    },
  _ => null,
};

/// Whether [parent] passes a string [child] through unchanged: parentheses
/// or a branch of a conditional expression.
bool isStringWrapper(AstNode parent, AstNode child) => switch (parent) {
  ParenthesizedExpression() => true,
  ConditionalExpression(:final condition) => child != condition,
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
