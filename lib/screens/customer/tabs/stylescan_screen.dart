// lib/screens/customer/tabs/stylescan_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geges_smartbarber/services/style_scan_service.dart';

class StyleScanScreen extends StatefulWidget {
  const StyleScanScreen({super.key});

  @override
  State<StyleScanScreen> createState() => _StyleScanScreenState();
}

class _StyleScanScreenState extends State<StyleScanScreen> {
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);
  static const Color kSurface = Colors.black;

  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  Map<String, dynamic>? _scanResult;

  // Base URL is configurable via `--dart-define=STYLE_SCAN_BASE_URL=http://your.vps:5000`
  // Fallback: http://0.0.0.0:5000 (use this only for local testing)
  final String _baseUrl = const String.fromEnvironment(
    'STYLE_SCAN_BASE_URL',
    defaultValue: 'http://0.0.0.0:5000',
  );
  late final StyleScanService _service = StyleScanService(baseUrl: _baseUrl);

  // --- Permission Helpers ---
  Future<bool> _ensurePermission(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted) return true;
    final result = await permission.request();
    return result.isGranted;
  }

  // --- Image Pickers ---
  Future<void> _pickImage(ImageSource source) async {
    Permission permission;
    if (source == ImageSource.camera) {
      permission = Permission.camera;
    } else {
      // Untuk Android 13+ lebih baik menggunakan photos, atau storage untuk yang lebih lama
      permission = Platform.isAndroid ? Permission.photos : Permission.photos;
    }

    if (!(await _ensurePermission(permission))) {
      _showSnack(
        'Akses ${source == ImageSource.camera ? 'Kamera' : 'Galeri'} ditolak.',
      );
      return;
    }

    try {
      final XFile? f = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (f != null) {
        setState(() {
          _pickedImage = File(f.path);
          // Di sini nanti Anda akan memanggil fungsi AI processing
          // _processImage(_pickedImage!);
          _scanResult = null;
        });
        // Start scan after UI updates
        _performScan();
      }
    } catch (e) {
      _showSnack('Gagal mengambil gambar: $e');
    }
  }

  Future<void> _performScan() async {
    if (_pickedImage == null) return;
    setState(() {
      _loading = true;
      _scanResult = null;
    });

    try {
      final resp = await _service.scanImage(_pickedImage!);
      if (mounted) setState(() => _scanResult = resp);
    } catch (e) {
      if (mounted) {
        _showSnack('Gagal scan: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: kBrownAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(icon, color: color, size: 40),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.style, color: kBrownAccent, size: 80),
          const SizedBox(height: 20),
          const Text(
            'Scan Gaya Rambut AI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          const SizedBox(height: 40),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.camera_alt,
                label: 'Ambil Foto',
                onTap: () => _pickImage(ImageSource.camera),
                color: kBrownAccent,
              ),
              const SizedBox(width: 30),
              _buildActionButton(
                icon: Icons.photo_library,
                label: 'Unggah Gambar',
                onTap: () => _pickImage(ImageSource.gallery),
                color: Colors.blueGrey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    // Tampilan hasil setelah gambar dipilih
    // Use API results when available, otherwise fall back to previous placeholders
    final detections =
        _scanResult != null &&
            _scanResult!['data'] != null &&
            _scanResult!['data']['detections'] is List
        ? List<Map<String, dynamic>>.from(
            (_scanResult!['data']['detections'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          )
        : null;

    final Map<String, dynamic>? first =
        (detections != null && detections.isNotEmpty) ? detections[0] : null;

    final detectedName = first != null
        ? (first['class_name'] ?? first['class_id'] ?? 'Unknown')
        : 'Taper Fade Klasik';
    final detectedConfidence = first != null && first['confidence'] != null
        ? '${((first['confidence'] as num) * 100).toStringAsFixed(0)}%'
        : '85%';
    final faceShape =
        _scanResult != null &&
            _scanResult!['data'] != null &&
            _scanResult!['data']['face_shape'] != null
        ? _scanResult!['data']['face_shape'].toString()
        : 'Oval';
    final description = _scanResult != null && _scanResult!['data'] != null
        ? 'Gaya ini terdeteksi sebagai $detectedName dengan tingkat kecocokan $detectedConfidence.'
        : 'Gaya ini cocok untuk Anda karena menonjolkan tekstur rambut atas dan rapi di sisi. Barbershop terdekat yang ahli dalam gaya ini adalah...';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hasil Scan Gaya',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => setState(() => _pickedImage = null),
              ),
            ],
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: LinearProgressIndicator(minHeight: 4),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 50),
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                height: 350,
                decoration: BoxDecoration(
                  color: kDarkGrey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    _pickedImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text(
                        "Error loading image",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Placeholder untuk Hasil Analisis AI
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analisis AI:',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: kDarkGrey,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAnalysisRow(
                            Icons.cut,
                            'Gaya Terdeteksi:',
                            detectedName,
                          ),
                          _buildAnalysisRow(
                            Icons.local_offer,
                            'Kecocokan:',
                            detectedConfidence,
                          ),
                          _buildAnalysisRow(
                            Icons.face,
                            'Bentuk Wajah:',
                            faceShape,
                          ),
                          const Divider(color: Colors.white12, height: 25),
                          const Text(
                            'Deskripsi:',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            description,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Aksi ke Booking
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        backgroundColor: kBrownAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Book Barbershop dengan Gaya Ini',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => _pickImage(ImageSource.camera),
                      child: const Text(
                        'Scan Ulang / Ambil Gambar Baru',
                        style: TextStyle(color: kBrownAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: kBrownAccent, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: _pickedImage == null ? _buildEmptyState() : _buildResultView(),
      ),
    );
  }
}
