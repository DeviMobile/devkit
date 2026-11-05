import 'dart:io';

import 'package:devimobile_devkit_cli/devimobile_devkit_cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runDevkit(args);
}
