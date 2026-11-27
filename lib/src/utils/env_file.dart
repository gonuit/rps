import 'package:rps/rps.dart';

/// Reads variables from the [content] of an env file named [path].
Map<String, String> parseEnvFile(String content, {required String path}) {
  final variables = <String, String>{};
  final lines = content.split(RegExp(r'\r?\n'));
  for (final (index, rawLine) in lines.indexed) {
    var line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trimLeft();

    final separator = line.indexOf('=');
    final name = separator < 0 ? '' : line.substring(0, separator).trim();
    if (name.isEmpty || name.contains(RegExp(r'\s'))) {
      throw RpsConfigException(
        'Invalid line ${index + 1} in the env file "$path". '
        'Expected NAME=VALUE.',
      );
    }
    variables[name] = _value(line.substring(separator + 1).trim());
  }
  return variables;
}

String _value(String value) {
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    return value.substring(1, value.length - 1).replaceAllMapped(
          RegExp(r'\\(.)'),
          (match) => switch (match[1]!) {
            'n' => '\n',
            't' => '\t',
            final other => other,
          },
        );
  }
  if (value.length >= 2 && value.startsWith("'") && value.endsWith("'")) {
    return value.substring(1, value.length - 1);
  }
  final comment = value.indexOf(RegExp(r'\s#'));
  return comment < 0 ? value : value.substring(0, comment).trimRight();
}
