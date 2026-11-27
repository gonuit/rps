import 'package:rps/rps.dart';

/// Updates rps to the latest version.
Future<void> upgrade(Console console, Platform platform) async {
  const command = 'dart pub global activate rps';
  console.write(
    '${boldBlue('\n⏳ Upgrading rps package...')}\n\n'
    '${boldGreen(r'$')} ${bold(command)}\n\n',
  );

  final exitCode = await execute(command, shell: Shell.of(null, platform));
  if (exitCode != 0) {
    throw ScriptFailedException(
      'Failed to update the rps package. '
      'Command ended with a non zero exit code.',
      exitCode: exitCode,
    );
  }

  console
    ..writeln()
    ..writeln(boldGreen('✓ rps updated successfully!'))
    ..writeln();
}
