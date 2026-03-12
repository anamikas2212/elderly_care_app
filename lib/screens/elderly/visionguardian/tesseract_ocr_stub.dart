import 'dart:typed_data';

// Stub implementation for non-web platforms.
// On mobile, TesseractOcr is never called — ML Kit is used instead.
class TesseractOcr {
  static Future<List<String>> recognizeFromBytes(Uint8List imageBytes) async {
    throw UnsupportedError('TesseractOcr is only available on web.');
  }
}
