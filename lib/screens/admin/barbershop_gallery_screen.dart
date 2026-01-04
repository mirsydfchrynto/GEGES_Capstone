import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

class BarbershopGalleryScreen extends StatefulWidget {
  final Barbershop barbershop;
  final BarbershopService? barbershopService;

  const BarbershopGalleryScreen({
    required this.barbershop,
    this.barbershopService,
    super.key,
  });

  @override
  State<BarbershopGalleryScreen> createState() =>
      _BarbershopGalleryScreenState();
}

class _BarbershopGalleryScreenState extends State<BarbershopGalleryScreen> {
  late final BarbershopService _service;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  late List<String> _gallery;

  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkSurface = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _service = widget.barbershopService ?? BarbershopService();
    _gallery = List.from(widget.barbershop.galleryUrls);
  }

  Future<void> _addImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 70,
      );
      
      if (image != null) {
        setState(() => _isLoading = true);
        final bytes = await File(image.path).readAsBytes();
        final base64String = base64Encode(bytes);
        
        await _service.addGalleryImage(widget.barbershop.id, base64String);
        
        setState(() {
          _gallery.add(base64String);
          _isLoading = false;
        });
        
        _showSnack('Image added to album!');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Error adding image: $e', isError: true);
    }
  }

  Future<void> _removeImage(String base64) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDarkSurface,
        title: const Text('Remove Photo', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this photo from gallery?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _service.removeGalleryImage(widget.barbershop.id, base64);
      setState(() {
        _gallery.remove(base64);
        _isLoading = false;
      });
      _showSnack('Image removed.');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Error removing image: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : kBrownAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Barbershop Album', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kBrownAccent,
        foregroundColor: Colors.black,
        actions: [
          if (!_isLoading)
            IconButton(icon: const Icon(Icons.add_photo_alternate_rounded), onPressed: _addImage),
        ],
      ),
      body: Stack(
        children: [
          _gallery.isEmpty
              ? const Center(child: Text('No photos in gallery.', style: TextStyle(color: Colors.white54)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _gallery.length,
                  itemBuilder: (context, index) {
                    final img = _gallery[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(base64Decode(img), fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: GestureDetector(
                            onTap: () => _removeImage(img),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: kBrownAccent)),
            ),
        ],
      ),
    );
  }
}