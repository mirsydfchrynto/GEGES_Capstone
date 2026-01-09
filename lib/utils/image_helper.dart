import 'dart:convert';
import 'dart:typed_data';

class ImageHelper {
  /// Decodes a base64 string, handling Data URI prefixes (e.g., data:image/png;base64,...)
  /// and removing any whitespace or newlines.
  static Uint8List decodeBase64(String base64String) {
    try {
      String cleanString = base64String;

      // Check for 'base64,' prefix
      if (base64String.contains('base64,')) {
        cleanString = base64String.split('base64,').last;
      } else if (base64String.contains(',')) {
        // Fallback for other data URI formats
        cleanString = base64String.split(',').last;
      }

      // Remove any whitespace or newlines
      cleanString = cleanString.replaceAll(RegExp(r'\s+'), '');

      return base64Decode(cleanString);
    } catch (e) {
      // Log the error if necessary
      return Uint8List(0);
    }
  }
}
