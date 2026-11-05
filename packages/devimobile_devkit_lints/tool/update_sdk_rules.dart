// Replaces tool/sdk_rules.json with the lint catalog of a Dart SDK version.
//
//   dart run tool/update_sdk_rules.dart              SDK running this script
//   dart run tool/update_sdk_rules.dart --sdk 3.13.7
//
// Afterwards run `dart test`: rules without a decision fail the completeness
// test until they get one in tool/decisions.yaml.
import 'dart:convert';
import 'dart:io';

import 'src/catalog.dart';

Future<void> main(List<String> args) async {
  final sdkIndex = args.indexOf('--sdk');
  final sdk = sdkIndex >= 0 && sdkIndex + 1 < args.length
      ? args[sdkIndex + 1]
      : Platform.version.split(' ').first;

  final url = SdkCatalog.sourceUrl(sdk);
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      stderr.writeln('GET $url failed: ${response.statusCode}');
      exitCode = 1;
      return;
    }
    final rules = (jsonDecode(body) as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(SdkRule.fromJson)
        .toList();
    final catalog = SdkCatalog(sdk: sdk, source: url, rules: rules);
    final target = File.fromUri(Platform.script.resolve('sdk_rules.json'));
    target.writeAsStringSync(catalog.toJsonString());
    stdout.writeln('tool/sdk_rules.json: ${rules.length} rules from SDK $sdk');
  } finally {
    client.close();
  }
}
