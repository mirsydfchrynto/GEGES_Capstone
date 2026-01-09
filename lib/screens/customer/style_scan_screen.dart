import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geges_smartbarber/services/style_scan_service.dart';

class StyleScanScreen extends StatefulWidget {
  const StyleScanScreen({super.key});

  @override
  State<StyleScanScreen> createState() => _StyleScanScreenState();
}

class _StyleScanScreenState extends State<StyleScanScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _loading = false;
  Map<String, dynamic>? _result;

  // Replace with your VPS URL
  final _service = StyleScanService(baseUrl: 'http://0.0.0.0:5000');

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _result = null;
    });
  }

  Future<void> _scan() async {
    if (_image == null) return;
    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final resp = await _service.scanImage(_image!);
      if (mounted) setState(() => _result = resp);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildResult() {
    if (_result == null) return const SizedBox();
    final status = _result!['status'] ?? 'unknown';
    final data = _result!['data'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status: $status',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (data != null) ...[
          Text('Count: ${data['count'] ?? 0}'),
          const SizedBox(height: 8),
          if (data['detections'] != null)
            ...List<Widget>.from(
              (data['detections'] as List).map(
                (d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${d['class_name'] ?? d['class_id']} - ${(d['confidence'] ?? 0).toStringAsFixed(2)}',
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Style Scan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_image != null)
              SizedBox(
                height: 240,
                child: Image.file(_image!, fit: BoxFit.cover),
              ),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo),
              label: const Text('Pick Image'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loading ? null : _scan,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: const Text('Scan Style'),
            ),
            const SizedBox(height: 12),
            _buildResult(),
          ],
        ),
      ),
    );
  }
}
