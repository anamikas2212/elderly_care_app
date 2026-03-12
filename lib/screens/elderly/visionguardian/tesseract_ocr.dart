import 'dart:js_interop';
import 'dart:js' as js ;
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

class TesseractOcr {
  static Future<List<String>> recognizeFromBytes(Uint8List imageBytes) async {
    final completer = Completer<List<String>>();

    final base64Str = base64Encode(imageBytes);
    final dataUrl = 'data:image/jpeg;base64,$base64Str';

    js.context.callMethod('runTesseract', [
      dataUrl,
      ((String result) {
        final words =
            result
                .split(RegExp(r'[\s\n]+'))
                .map((w) => w.trim())
                .where((w) => w.isNotEmpty)
                .toList();
        completer.complete(words);
      }).toJS, // ✅ Modern way to pass Dart fn to JS
      ((String error) {
        completer.completeError(error);
      }).toJS, // ✅ .toJS replaces allowInterop
    ]);

    return completer.future;
  }
}
