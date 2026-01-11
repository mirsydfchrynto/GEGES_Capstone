import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geges_smartbarber/services/ai_service.dart';


// Theme Constants
const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Color(0xFF121212);

class StyleScanScreen extends StatefulWidget {
  const StyleScanScreen({super.key});

  @override
  State<StyleScanScreen> createState() => _StyleScanScreenState();
}

class _StyleScanScreenState extends State<StyleScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final AIService _service = AIService();
  
  File? _image;
  bool _loading = false;
  Map<String, dynamic>? _result;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;
      
      setState(() {
        _image = File(picked.path);
        _result = null;
      });
    } catch (e) {
      debugPrint("Pick Image Error: $e");
    }
  }

  Future<void> _scan() async {
    if (_image == null) return;
    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final resp = await _service.scanImage(_image!);
      if (mounted) {
        setState(() => _result = resp);
        
        if (resp['success'] == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resp['message'] ?? 'Gagal memproses gambar')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      extendBodyBehindAppBar: true, // Elegant full-screen effect
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text('AI Style Scanner', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background / Image Preview
          Positioned.fill(
            child: _image != null
                ? Image.file(_image!, fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kDarkGrey, Colors.black],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.face_retouching_natural, size: 80, color: kBrownAccent.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            "Scan wajahmu untuk rekomendasi\ngaya rambut terbaik",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Dark Gradient Overlay at Bottom
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9), Colors.black],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),

          // Content Area (Buttons & Results)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_result != null && _result!['success'] == true) 
                    _buildResultCard(_result!['data']),

                  const SizedBox(height: 24),

                  if (_loading)
                    const Center(child: CircularProgressIndicator(color: kBrownAccent))
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.photo_library, 
                            label: 'Galeri',
                            onTap: () => _pickImage(ImageSource.gallery),
                            isPrimary: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.camera_alt, 
                            label: 'Kamera',
                            onTap: () => _pickImage(ImageSource.camera),
                            isPrimary: false,
                          ),
                        ),
                        if (_image != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2, // Bigger button for Scan
                            child: _buildActionButton(
                              icon: Icons.search, 
                              label: 'SCAN SEKARANG',
                              onTap: _scan,
                              isPrimary: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon, 
    required String label, 
    required VoidCallback onTap, 
    required bool isPrimary
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? kBrownAccent : Colors.white10,
        foregroundColor: isPrimary ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: isPrimary ? 8 : 0,
        shadowColor: isPrimary ? kBrownAccent.withValues(alpha: 0.4) : Colors.transparent,
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> data) {
    final bestMatch = data['best_match'] ?? {};
    final String label = bestMatch['label'] ?? 'Unknown';
    final double confidence = bestMatch['confidence'] ?? 0.0;
    final String note = data['note'] ?? '';
    final List alternatives = data['alternatives'] ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBrownAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("HASIL DETEKSI", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(
                    label.toUpperCase(), 
                    style: const TextStyle(color: kBrownAccent, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              _buildConfidenceBadge(confidence),
            ],
          ),
          const SizedBox(height: 16),
          
          if (note.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(note, style: const TextStyle(color: Colors.amber, fontSize: 12)),
                  ),
                ],
              ),
            ),

          if (alternatives.isNotEmpty) ...[
            const Text("Alternatif Lain:", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: alternatives.map((alt) {
                final altLabel = alt['label'];
                final altConf = ((alt['confidence'] ?? 0) * 100).toStringAsFixed(0);
                return Chip(
                  backgroundColor: Colors.white10,
                  label: Text("$altLabel ($altConf%)", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  avatar: const CircleAvatar(backgroundColor: Colors.white24, radius: 8),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(double confidence) {
    Color color = Colors.green;
    if (confidence < 0.5) {
      color = Colors.red;
    } else if (confidence < 0.8) {
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            "${(confidence * 100).toStringAsFixed(0)}%",
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}