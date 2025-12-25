// [ANDA BISA COPY PASTE MULAI DARI SINI]
// NAMA FILE: lib/screens/customer/tabs/review_tab.dart

import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barbershop.dart';

class ReviewTab extends StatelessWidget {
  final Barbershop shop;
  ReviewTab({super.key, required this.shop});

  // Data dummy untuk Reviews (sesuai review.png)
  final List<Map<String, dynamic>> _dummyReviews = [
    {
      "name": "Irsyad F.",
      "rating": 5.0,
      "date": "2d ago",
      "comment":
          "Tempatnya nyaman dan bersih. Barbermannya (Agus) sangat profesional dan hasilnya rapi. Pasti balik lagi!",
      "image":
          "https://placehold.co/100x100/C3A47B/000000?text=IF", // Placeholder foto profil
    },
    {
      "name": "Budi Santoso",
      "rating": 4.0,
      "date": "5d ago",
      "comment": "Good service, harga terjangkau. Wifi kencang. Recommended.",
      "image": "https://placehold.co/100x100/FFFFFF/000000?text=BS",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(24.0),
      itemCount: _dummyReviews.length,
      itemBuilder: (context, index) {
        final review = _dummyReviews[index];
        return _buildReviewCard(review);
      },
      separatorBuilder: (context, index) =>
          const Divider(color: Colors.white12, height: 32),
    );
  }

  // Widget untuk 1 card review
  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris 1: Foto, Nama, Rating, Tanggal
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto Profil
            CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(review['image'] as String),
            ),
            const SizedBox(width: 16),
            // Nama & Rating
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review['name'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFC3A47B),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        review['rating'].toString(),
                        style: const TextStyle(
                          color: Color(0xFFC3A47B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tanggal
            Text(
              review['date'] as String,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Baris 2: Komentar
        Text(
          review['comment'] as String,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// [ANDA BISA COPY PASTE SAMPAI SINI]
