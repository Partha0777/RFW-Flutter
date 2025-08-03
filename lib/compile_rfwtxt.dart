// tool/compile_rfwtxt.dart
import 'dart:io';
import 'package:rfw/formats.dart'; // ✅ pure-Dart parse/encode (no dart:ui)

void main(List<String> args) {
  // You can pass args, or it will use your hardcoded paths:
  final inputPath  = args[0];
  final outputPath = args[1];

  if (!File(inputPath).existsSync()) {
    stderr.writeln('❌ Input not found: $inputPath');
    exit(66); // EX_NOINPUT
  }

  try {
    final txt = File(inputPath).readAsStringSync();

    // Parse text -> library (rfwtxt only allows import/widget constructs)
    final lib = parseLibraryFile(txt, sourceIdentifier: inputPath);

    // Encode library -> binary blob
    final bytes = encodeLibraryBlob(lib);

    File(outputPath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    stdout.writeln('✅ Compiled $inputPath → $outputPath (${bytes.length} bytes)');
  } catch (e, st) {
    stderr.writeln('❌ Compile failed: $e');
    stderr.writeln(st);
    exit(1);
  }
}
