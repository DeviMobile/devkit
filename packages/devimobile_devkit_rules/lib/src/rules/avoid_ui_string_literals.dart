import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:devimobile_devkit_rules/src/elements.dart';

/// Reports user-facing text written as a string literal: the text of
/// `Text('…')` and the Flutter parameters `tooltip`, `semanticsLabel`,
/// `semanticLabel`, `hintText` and `labelText`.
///
/// Only literals with a letter are reported, so `''`, `'$count'` and `'•'`
/// pass.
class AvoidUiStringLiterals extends AnalysisRule {
  /// Creates the rule.
  AvoidUiStringLiterals()
    : super(
        name: 'avoid_ui_string_literals',
        description:
            'User-facing text comes from localizations, not from string '
            'literals.',
      );

  /// The reported diagnostic.
  static const code = LintCode(
    'avoid_ui_string_literals',
    "User-facing text in a string literal ('{0}').",
    correctionMessage: 'Try using a localized string.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Named parameters of Flutter APIs that take user-facing text.
  static const parameterNames = {
    'tooltip',
    'semanticsLabel',
    'semanticLabel',
    'hintText',
    'labelText',
  };

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
      ..addSimpleStringLiteral(this, visitor)
      ..addAdjacentStrings(this, visitor)
      ..addStringInterpolation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidUiStringLiterals rule;

  @override
  void visitAdjacentStrings(AdjacentStrings node) => _check(node);

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) => _check(node);

  @override
  void visitStringInterpolation(StringInterpolation node) => _check(node);

  void _check(StringLiteral literal) {
    // The parts of `'a' 'b'` are checked together, through the parent.
    if (literal.parent is AdjacentStrings) return;
    if (!hasLetters(literal)) return;
    final found = enclosingArgument(literal, isWrapper: isStringWrapper);
    if (found == null) return;
    final parameter = receivingParameter(found.argument);
    if (parameter == null || !_takesUiText(parameter)) return;
    rule.reportAtNode(
      literal,
      arguments: [if (parameter.isNamed) parameter.name ?? '' else 'Text'],
    );
  }

  static bool _takesUiText(FormalParameterElement parameter) {
    if (!isFromFlutter(parameter)) return false;
    final name = parameter.name;
    if (parameter.isNamed) {
      return AvoidUiStringLiterals.parameterNames.contains(name);
    }
    final constructor = parameter.enclosingElement;
    return name == 'data' &&
        constructor is ConstructorElement &&
        constructor.enclosingElement.name == 'Text';
  }
}
