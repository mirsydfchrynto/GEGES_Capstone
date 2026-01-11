import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geges_smartbarber/utils/image_helper.dart';

import 'package:geges_smartbarber/services/tenant_service.dart';

class DocumentUploadWidget extends StatefulWidget {
  final String tenantId;
  final TenantService tenantService;
  final String label;
  final String? existingUrl;
  final void Function(String url) onUploaded;

  /// Optional override for file picking in tests.
  /// If provided, should return a path to the picked file, or null if cancelled.
  final Future<String?> Function()? filePicker;
  final bool darkStyle;

  const DocumentUploadWidget({
    super.key,
    required this.tenantId,
    required this.tenantService,
    required this.label,
    this.existingUrl,
    required this.onUploaded,
    this.filePicker,
    this.darkStyle = false,
  });

  @override
  State<DocumentUploadWidget> createState() => _DocumentUploadWidgetState();
}

class _DocumentUploadWidgetState extends State<DocumentUploadWidget> {
  bool _isUploading = false;
  String? _uploadedUrl;

  Future<void> _pickAndUpload() async {
    // If test filePicker provided, use it directly (bypass UI)
    if (widget.filePicker != null) {
      final path = await widget.filePicker!.call();
      if (path != null) _processFile(File(path));
      return;
    }

    // Show selection sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.darkStyle ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFC3A47B)),
              title: Text(
                'Ambil Foto (Kamera)', 
                style: TextStyle(color: widget.darkStyle ? Colors.white : Colors.black)
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFC3A47B)),
              title: Text(
                'Pilih dari Galeri',
                style: TextStyle(color: widget.darkStyle ? Colors.white : Colors.black)
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Color(0xFFC3A47B)),
              title: Text(
                'Pilih Dokumen (PDF)',
                style: TextStyle(color: widget.darkStyle ? Colors.white : Colors.black)
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await ImageHelper().pickAndCompress(
      source: source,
      quality: 70, // Optimize quality for docs
      maxWidth: 1200, // Slightly larger for docs readability
    );
    if (file != null) _processFile(file);
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );
    if (res != null && res.files.single.path != null) {
      _processFile(File(res.files.single.path!));
    }
  }

  Future<void> _processFile(File file) async {
    setState(() {
      _isUploading = true;
    });

    try {
      // Check file size (Hard limit 1MB for Firestore Base64 safety)
      final size = await file.length();
      if (size > 1000000) { // 1MB
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Ukuran file terlalu besar (>1MB). Gunakan opsi Kamera/Galeri untuk kompresi otomatis.')),
           );
         }
         return;
      }

      final ref = await widget.tenantService.uploadTenantDocument(
        widget.tenantId,
        file,
      );
      setState(() {
        _uploadedUrl = ref;
      });
      widget.onUploaded(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload gagal: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = _uploadedUrl ?? widget.existingUrl;
    final titleStyle = widget.darkStyle
        ? const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
        : const TextStyle(fontWeight: FontWeight.bold);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: widget.darkStyle
          ? BoxDecoration(
              color: const Color(0xFF1B1B1B),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: titleStyle),
          const SizedBox(height: 6),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndUpload,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _isUploading ? 'Mengunggah...' : 'Unggah',
                  style: widget.darkStyle
                      ? const TextStyle(color: Colors.black)
                      : null,
                ),
                style: widget.darkStyle
                    ? ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB9976E),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              if (_isUploading) const CircularProgressIndicator(),
              if (displayUrl != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.darkStyle ? 'Tersimpan' : 'Tersimpan',
                    overflow: TextOverflow.ellipsis,
                    style: widget.darkStyle
                        ? const TextStyle(color: Colors.white)
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
