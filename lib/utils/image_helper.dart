import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageHelper {
  static final ImageHelper _instance = ImageHelper._internal();
  factory ImageHelper() => _instance;
  ImageHelper._internal();

  final ImagePicker _picker = ImagePicker();

  /// Helper to decode Base64 string to Uint8List safely
  static Uint8List decodeBase64(String base64String) {
    try {
      // Remove header if present (e.g. "data:image/png;base64,")
      if (base64String.contains(',')) {
        base64String = base64String.split(',').last;
      }
      return base64Decode(base64String);
    } catch (e) {
      debugPrint('Error decoding base64: $e');
      return Uint8List(0);
    }
  }

  /// Pick image from source, resize, and compress it.
  /// Returns null if user cancels.
  Future<File?> pickAndCompress({
    required ImageSource source,
    int quality = 70,
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    try {
      // 1. Pick Image
      final XFile? picked = await _picker.pickImage(source: source);
      if (picked == null) return null;

      // 2. Compress Image
      // We create a temp target path
      final Directory tempDir = await getTemporaryDirectory();
      final String targetPath = p.join(
        tempDir.path, 
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg'
      );

      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (compressed == null) {
        // Fallback if compression fails (rare)
        return File(picked.path);
      }

      final File result = File(compressed.path);
      
      // Log for debugging size reduction
      final int originalSize = await File(picked.path).length();
      final int compressedSize = await result.length();
      debugPrint('Image Compression: ${(originalSize/1024).toStringAsFixed(2)}KB -> ${(compressedSize/1024).toStringAsFixed(2)}KB');

      return result;
    } catch (e) {
      debugPrint('Error picking/compressing image: $e');
      return null;
    }
  }

  /// Helper to convert File to Base64 (optimized)
  /// This should run in isolate ideally, but for <200KB files, main thread is OK-ish.
  /// Since we compressed it first, it won't block UI as much.
  Future<List<int>> fileToBytes(File file) async {
    return await file.readAsBytes();
  }
}