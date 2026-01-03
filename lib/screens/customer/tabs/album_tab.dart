import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barbershop.dart';

class AlbumTab extends StatelessWidget {
  final Barbershop shop;
  const AlbumTab({super.key, required this.shop});

  static const Color kBrownAccent = Color(0xFFC3A47B);

  @override
  Widget build(BuildContext context) {
    if (shop.galleryUrls.isEmpty) {
      return const Center(
        child: Text('No photos in gallery.', style: TextStyle(color: Colors.white54)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: shop.galleryUrls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final img = shop.galleryUrls[index];
        return GestureDetector(
          onTap: () => _showImagePreview(context, img),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(base64Decode(img), fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  void _showImagePreview(BuildContext context, String base64) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Center(child: InteractiveViewer(child: Image.memory(base64Decode(base64)))),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}