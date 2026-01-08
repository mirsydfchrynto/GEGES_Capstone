import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geges_smartbarber/models/barbershop.dart';

class AlbumTab extends StatelessWidget {
  final Barbershop shop;
  const AlbumTab({super.key, required this.shop});

  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);

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
            child: _buildImageWidget(img),
          ),
        );
      },
    );
  }

  Widget _buildImageWidget(String path) {
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: kDarkGrey),
        errorWidget: (context, url, error) => Container(
          color: kDarkGrey,
          child: const Center(child: Icon(Icons.broken_image, color: kBrownAccent, size: 30)),
        ),
      );
    } else if (path.length > 200) {
      try {
        return Image.memory(base64Decode(path), fit: BoxFit.cover);
      } catch (e) {
        return Container(
          color: kDarkGrey,
          child: const Center(child: Icon(Icons.broken_image, color: kBrownAccent, size: 30)),
        );
      }
    } else {
      return Image.asset(path, fit: BoxFit.cover);
    }
  }

  void _showImagePreview(BuildContext context, String base64) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Center(child: InteractiveViewer(child: _buildImageWidget(base64))),
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
