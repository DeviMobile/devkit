/// Entry point of the `devimobile_devkit_rules` analyzer plugin.
///
/// The Dart analysis server imports this library and reads [plugin]. Enable
/// the plugin in `analysis_options.yaml`; see the package README.
library;

import 'package:devimobile_devkit_rules/devimobile_devkit_rules.dart';

/// The plugin instance the analysis server loads.
final plugin = DevkitRulesPlugin();
