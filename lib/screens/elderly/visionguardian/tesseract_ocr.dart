import 'dart:js' as js;
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

class TesseractOcr {
  /// Recognizes text from image bytes using Tesseract.js (web only).
  static Future<List<String>> recognizeFromBytes(Uint8List imageBytes) async {
    final completer = Completer<List<String>>();

    // Convert bytes to base64 data URL
    final base64Str = base64Encode(imageBytes);
    final dataUrl = 'data:image/jpeg;base64,$base64Str';

    // Call the global runTesseract() function defined in index.html
    js.context.callMethod('runTesseract', [
      dataUrl,
      js.allowInterop((String result) {
        final words =
            result
                .split(RegExp(r'[\s\n]+'))
                .map((w) => w.trim())
                .where((w) => w.isNotEmpty)
                .toList();
        completer.complete(words);
      }),
      js.allowInterop((String error) {
        completer.completeError(error);
      }),
    ]);

    return completer.future;
  }
}
