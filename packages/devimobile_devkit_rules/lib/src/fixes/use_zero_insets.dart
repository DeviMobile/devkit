import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';
import 'package:devimobile_devkit_rules/src/elements.dart';

/// Replaces insets whose literal arguments are all zero, such as
/// `EdgeInsets.all(0)`, with the `zero` constant of the same class.
class UseZeroInsets extends ResolvedCorrectionProducer {
  /// Creates the fix for the diagnostic in [context].
  UseZeroInsets({required super.context});

  static const _kind = FixKind(
    'devimobile_devkit_rules.fix.useZeroInsets',
    DartFixKindPriority.standard,
    "Replace with '{0}'",
  );

  static const _multiKind = FixKind(
    'devimobile_devkit_rules.fix.useZeroInsets.multi',
    DartFixKindPriority.inFile,
    'Replace zero insets with the zero constant everywhere in file',
  );

  var _replacement = '';

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.acrossFiles;

  @override
  List<String> get fixArguments => [_replacement];

  @override
  FixKind get fixKind => _kind;

  @override
  FixKind get multiFixKind => _multiKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final invocation = node;
    final (arguments, typeName) = switch (invocation) {
      InstanceCreationExpression(:final argumentList, :final constructorName) =>
        (argumentList, constructorName.type.toSource()),
      DotShorthandConstructorInvocation(:final argumentList) => (
        argumentList,
        '',
      ),
      _ => (null, ''),
    };
    if (arguments == null || arguments.arguments.isEmpty) return;
    final allZero = arguments.arguments
        .map(argumentValue)
        .every((value) => numericLiteralValue(value) == 0);
    if (!allZero) return;

    _replacement = '$typeName.zero';
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(invocation), _replacement);
    });
  }
}
