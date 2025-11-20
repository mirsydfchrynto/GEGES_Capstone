// lib/screens/admin/barbershop_gallery_screen.dart
// dokumentasi: admin screen untuk manage galeri foto barbershop

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:geges_smartbarber/services/barbershop_gallery_service.dart';

class BarbershopGalleryScreen extends StatefulWidget {
  final String barbershopId;
  final String barbershopName;

  const BarbershopGalleryScreen({
    super.key,
    required this.barbershopId,
    required this.barbershopName,
  });

  @override
  State<BarbershopGalleryScreen> createState() =>
      _BarbershopGalleryScreenState();
}

class _BarbershopGalleryScreenState extends State<BarbershopGalleryScreen> {
  final BarbershopGalleryService _galleryService = BarbershopGalleryService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Galeri: ${widget.barbershopName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                _isUploading ? 'Uploading...' : 'Ready',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<String>>(
        stream: _galleryService.streamPhotoUrls(widget.barbershopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final photoUrls = snapshot.data ?? [];

          return SingleChildScrollView(
            child: Column(
              children: [
                // Upload button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _pickAndUploadImage,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Tambah Foto'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),

                // Gallery grid
                if (photoUrls.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada foto\nTambahkan foto pertama Anda',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: photoUrls.length,
                      itemBuilder: (context, index) {
                        final url = photoUrls[index];
                        return _PhotoCard(
                          imageUrl: url,
                          onDelete: () => _deletePhoto(url),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      final file = File(pickedFile.path);
      final url = await _galleryService.uploadPhoto(
        widget.barbershopId,
        file,
      );

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (url != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto berhasil diupload')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload: $e')),
        );
      }
    }
  }

  Future<void> _deletePhoto(String photoUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Foto'),
        content: const Text('Apakah Anda yakin ingin menghapus foto ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _galleryService.deletePhoto(widget.barbershopId, photoUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto dihapus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    }
  }
}

// -----------------------
// PHOTO CARD WIDGET
// -----------------------
class _PhotoCard extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onDelete;

  const _PhotoCard({
    required this.imageUrl,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Image
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showImagePreview(context),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                   color: Colors.black.withValues(alpha: 0),
                ),
              ),
            ),
          ),
        ),

        // Delete button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showImagePreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
