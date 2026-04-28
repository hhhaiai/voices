import 'dart:io';

const _profiles = <String, List<String>>{
  'local-all': [
    'assets/models/whisper-tiny/',
    'assets/models/vosk-cn/',
    'assets/models/sensevoice-onnx/',
  ],
  'release-whisper': [
    'assets/models/whisper-tiny/',
  ],
  'release-whisper-sensevoice': [
    'assets/models/whisper-tiny/',
    'assets/models/sensevoice-onnx/',
  ],
};

void main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    exit(args.isEmpty ? 1 : 0);
  }

  if (args.length == 1 && args.first == '--list') {
    stdout.writeln('Available profiles:');
    for (final entry in _profiles.entries) {
      stdout.writeln('- ${entry.key}: ${entry.value.join(', ')}');
    }
    return;
  }

  final profile = args.first.trim();
  final assets = _profiles[profile];
  if (assets == null) {
    stderr.writeln('Unknown profile: $profile');
    _printUsage();
    exit(2);
  }

  final pubspec = File('pubspec.yaml');
  if (!await pubspec.exists()) {
    stderr.writeln(
        'pubspec.yaml not found. Run this script from voices-flutter/.');
    exit(3);
  }

  final original = await pubspec.readAsString();
  const beginMarker = '    # MODEL_BUNDLE_BEGIN';
  const endMarker = '    # MODEL_BUNDLE_END';

  final begin = original.indexOf(beginMarker);
  final end = original.indexOf(endMarker);
  if (begin == -1 || end == -1 || end <= begin) {
    stderr.writeln('MODEL_BUNDLE markers not found in pubspec.yaml');
    exit(4);
  }

  final replacement = StringBuffer()
    ..writeln(beginMarker)
    ..writeAll(
      assets.map((asset) => '    - $asset'),
      '\n',
    )
    ..writeln()
    ..write(endMarker);

  final updated = original.replaceRange(
    begin,
    end + endMarker.length,
    replacement.toString(),
  );

  if (updated == original) {
    stdout.writeln('Model bundle profile already set to $profile');
    return;
  }

  await pubspec.writeAsString(updated);
  stdout.writeln('Updated pubspec.yaml to model bundle profile: $profile');
  stdout.writeln('Bundled assets:');
  for (final asset in assets) {
    stdout.writeln('- $asset');
  }
  stdout.writeln('Run `flutter pub get` before the next build.');
}

void _printUsage() {
  stdout
      .writeln('Usage: dart run tool/set_model_bundle_profile.dart <profile>');
  stdout.writeln('       dart run tool/set_model_bundle_profile.dart --list');
  stdout.writeln('');
  stdout.writeln('Profiles:');
  for (final entry in _profiles.entries) {
    stdout.writeln('- ${entry.key}: ${entry.value.join(', ')}');
  }
}
