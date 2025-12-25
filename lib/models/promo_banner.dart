// [ANDA BISA COPY PASTE MULAI DARI SINI]
// NAMA FILE: lib/models/promo_banner.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PromoBanner {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl; // <-- Sesuai permintaan Anda (pakai gambar)
  final bool isActive;

  PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.isActive,
  });

  // Factory constructor untuk membaca data dari Firestore
  factory PromoBanner.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {}; // Pola aman (jika data null)

    return PromoBanner(
      id: doc.id,
      title: data['title'] as String? ?? 'Promo Spesial',
      subtitle: data['subtitle'] as String? ?? 'Cek promonya sekarang!',

      // Ambil imageUrl, berikan placeholder jika field-nya kosong/null
      imageUrl:
          data['imageUrl'] as String? ??
          'https://placehold.co/600x400/C3A47B/000000?text=Geges+Promo',

      isActive: data['isActive'] as bool? ?? true,
    );
  }
}

// [ANDA BISA COPY PASTE SAMPAI SINI]
