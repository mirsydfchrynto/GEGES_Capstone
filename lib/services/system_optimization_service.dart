import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SystemOptimizationService {
  static final SystemOptimizationService instance = SystemOptimizationService._();
  SystemOptimizationService._();

  /// Membersihkan cache aplikasi secara cerdas
  /// - Menghapus file sementara (temporary directory)
  /// - Menghapus cache image dari memory
  /// - Menjaga data login (SharedPreferences) tetap aman
  Future<void> clearAppCache() async {
    try {
      debugPrint('🚀 [Optimization] Memulai pembersihan cache sistem...');

      // 1. Clear Image Cache from Memory
      CachedNetworkImage.evictFromCache(''); // Placeholder call to check connectivity
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      debugPrint('✅ Memory Image Cache dibersihkan');

      // 2. Clear Temporary Directory (Disk Cache)
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        if (tempDir.existsSync()) {
          await for (var entity in tempDir.list(recursive: true, followLinks: false)) {
            try {
              if (entity is File) {
                await entity.delete();
              } else if (entity is Directory) {
                // Jangan hapus direktori utama tempDir sendiri
                if (entity.path != tempDir.path) {
                  await entity.delete(recursive: true);
                }
              }
            } catch (e) {
              // Abaikan file yang sedang dikunci sistem
            }
          }
          debugPrint('✅ Disk Temporary Cache dibersihkan: ${tempDir.path}');
        }
      }

      debugPrint('🏁 [Optimization] Pembersihan selesai. Aplikasi kini lebih ringan.');
    } catch (e) {
      debugPrint('❌ [Optimization] Gagal membersihkan cache: $e');
    }
  }

  /// Optimasi Memory saat aplikasi berjalan berat
  void optimizeMemory() {
    PaintingBinding.instance.imageCache.clear();
    debugPrint('⚡ [Optimization] Low memory signal: Image cache cleared');
  }
}
