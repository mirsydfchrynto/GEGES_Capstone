// lib/screens/customer/tabs/stylescan_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geges_smartbarber/services/style_scan_service.dart';
import 'package:geges_smartbarber/screens/customer/style_booking_shop_selection_screen.dart';
import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';

class StyleScanScreen extends StatefulWidget {
  final StyleScanService? service;
  final ImagePicker? imagePicker;
  
  const StyleScanScreen({super.key, this.service, this.imagePicker});

  @override
  State<StyleScanScreen> createState() => _StyleScanScreenState();
}

class _StyleScanScreenState extends State<StyleScanScreen> {
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);
  static const Color kSurface = Colors.black;

  File? _pickedImage;
  late final ImagePicker _picker;
  bool _loading = false;
  String? _errorMessage; // Untuk error teknis (Network/Server)
  Map<String, dynamic>? _scanResult;

  // Base URL is configurable via `--dart-define=STYLE_SCAN_BASE_URL=http://your.vps:5000`
  // Fallback: https://mirsydfchyrnto-stylescan-api.hf.space
  final String _baseUrl = const String.fromEnvironment(
    'STYLE_SCAN_BASE_URL',
    defaultValue: 'https://mirsydfchyrnto-stylescan-api.hf.space',
  );
  late final StyleScanService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StyleScanService(baseUrl: _baseUrl);
    _picker = widget.imagePicker ?? ImagePicker();
  }

  // --- Permission Helpers ---
  Future<bool> _ensurePermission(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted) return true;
    final result = await permission.request();
    return result.isGranted;
  }

  // --- Image Pickers ---
  Future<void> _pickImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    Permission permission;
    if (source == ImageSource.camera) {
      permission = Permission.camera;
    } else {
      permission = Platform.isAndroid ? Permission.photos : Permission.photos;
    }

    if (!(await _ensurePermission(permission))) {
      _showSnack(
        source == ImageSource.camera ? l10n.cameraAccessDenied : l10n.galleryAccessDenied,
      );
      return;
    }

    try {
      final XFile? f = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1080, // Resize agar upload lebih cepat
      );
      if (f != null) {
        setState(() {
          _pickedImage = File(f.path);
          _scanResult = null;
          _errorMessage = null;
        });
        // Start scan automatically
        _performScan();
      }
    } catch (e) {
      _showSnack(l10n.errPickImage(e.toString()));
    }
  }

  Future<void> _performScan() async {
    if (_pickedImage == null) return;
    
    setState(() {
      _loading = true;
      _scanResult = null;
      _errorMessage = null;
    });

    try {
      final resp = await _service.scanImage(_pickedImage!);
      if (mounted) setState(() => _scanResult = resp);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
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
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.center_focus_weak, color: kBrownAccent, size: 100),
          const SizedBox(height: 30),
          Text(
            l10n.styleScanTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "Temukan gaya rambut terbaik yang cocok dengan bentuk wajahmu menggunakan AI.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.camera_alt,
                label: l10n.takePhoto,
                onTap: () => _pickImage(ImageSource.camera),
                color: kBrownAccent,
              ),
              const SizedBox(width: 40),
              _buildActionButton(
                icon: Icons.photo_library,
                label: l10n.uploadImage,
                onTap: () => _pickImage(ImageSource.gallery),
                color: Colors.blueGrey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Menampilkan Error Teknis (bukan hasil kosong AI)
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.redAccent, size: 60),
            const SizedBox(height: 20),
            const Text(
              "Gagal Terhubung ke AI",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? "Terjadi kesalahan tidak terduga.",
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _performScan,
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrownAccent,
                foregroundColor: Colors.black,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _pickedImage = null), 
              child: const Text("Ganti Foto", style: TextStyle(color: Colors.white54))
            )
          ],
        ),
      ),
    );
  }

  /// Menampilkan Hasil Scan (Valid atau Empty)
  Widget _buildScanContent() {
    final l10n = AppLocalizations.of(context)!;
    
    // Parse result
    final status = _scanResult?['status'] as String?;
    final data = _scanResult?['data'] as Map<String, dynamic>?;
    final note = data?['note'] as String? ?? _scanResult?['message'] as String? ?? 'Tidak dapat menganalisa gambar ini.';

    // A. Handle "empty" status (Low Accuracy / Invalid Object)
    if (status == 'empty') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.face_retouching_off, color: Colors.orange, size: 70),
              const SizedBox(height: 20),
              const Text(
                "Gaya Tidak Dikenali",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Text(
                  note,
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text("Foto Ulang (Wajah Jelas)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrownAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(200, 45),
                ),
              ),
              const SizedBox(height: 12),
               TextButton(
                onPressed: () => _pickImage(ImageSource.gallery),
                child: Text(l10n.uploadImage, style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      );
    }

    // B. Handle Success or Warning
    final bestMatch = data?['best_match'] as Map<String, dynamic>?;
    
    // Prioritize 'label' (new API) over 'class' (old API)
    final detectedName = bestMatch?['label'] ?? bestMatch?['class'] ?? 'Unknown Style';
    final rawConfidence = bestMatch?['confidence'] ?? bestMatch?['score'] ?? 0.0;
    final detectedConfidence = '${((rawConfidence is num ? rawConfidence : 0) * 100).toStringAsFixed(0)}%';
    
    final faceShape = data?['face_shape']?.toString() ?? 'Universal';
    
    // Description logic
    String description = bestMatch != null
        ? 'Gaya ini terdeteksi sebagai $detectedName dengan tingkat kecocokan $detectedConfidence. Cocok untuk bentuk wajah $faceShape.'
        : 'Silakan ambil foto untuk memulai analisis.';
    
    // If status is warning, prepend/append note or make description cautious
    if (status == 'warning') {
      description = "⚠️ $note\n\n$description";
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 50),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.aiAnalysis,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kDarkGrey,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnalysisRow(Icons.cut, l10n.detectedStyle, detectedName, isHighlight: true),
                    const SizedBox(height: 12),
                    _buildAnalysisRow(Icons.local_offer, l10n.confidence, detectedConfidence),
                    const SizedBox(height: 12),
                    _buildAnalysisRow(Icons.face, l10n.faceShape, faceShape),
                    const Divider(color: Colors.white12, height: 30),
                    Text(
                      l10n.descriptionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        color: status == 'warning' ? Colors.orangeAccent : Colors.white70, 
                        height: 1.5
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () {
                  final styleNote = "AI Style Scan: $detectedName ($detectedConfidence match) for $faceShape face.";
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StyleBookingShopSelectionScreen(
                        styleNote: styleNote,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: kBrownAccent,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shadowColor: kBrownAccent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  l10n.bookWithThisStyle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Center(
                child: TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.refresh, color: kBrownAccent, size: 18),
                  label: Text(
                    l10n.rescan,
                    style: const TextStyle(color: kBrownAccent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.scanResultTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => setState(() {
                  _pickedImage = null;
                  _scanResult = null;
                  _errorMessage = null;
                }),
              ),
            ],
          ),
        ),
        
        // Image Preview Area
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Background Image (Blurred/Darkened)
                  Image.file(
                    _pickedImage!,
                    fit: BoxFit.cover,
                    color: Colors.black54, // Darken background
                    colorBlendMode: BlendMode.darken,
                  ),
                  
                  // 2. Content (Error, Loading, or Result)
                  if (_errorMessage != null)
                    _buildErrorView()
                  else if (_loading)
                    _buildLoadingOverlay()
                  else
                    Column(
                      children: [
                        // Small Preview
                        const SizedBox(height: 20),
                        Container(
                          height: 200,
                          width: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kBrownAccent, width: 3),
                            image: DecorationImage(
                              image: FileImage(_pickedImage!),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: [
                              BoxShadow(color: kBrownAccent.withValues(alpha: 0.3), blurRadius: 20)
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Result Scrollable
                        Expanded(child: _buildScanContent()),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            color: kBrownAccent,
            strokeWidth: 6,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Menganalisa Gaya...",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "AI sedang memindai detail wajah dan rambut",
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildAnalysisRow(IconData icon, String label, String value, {bool isHighlight = false}) {
    return Row(
      children: [
        Icon(icon, color: kBrownAccent, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white70)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? kBrownAccent : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isHighlight ? 18 : 15,
          ),
        ),
      ],
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
