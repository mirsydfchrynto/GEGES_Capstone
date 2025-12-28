import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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
    String? path;
    if (widget.filePicker != null) {
      path = await widget.filePicker!.call();
      if (path == null) {
        return;
      }
    } else {
      final res = await FilePicker.platform.pickFiles(allowMultiple: false);
      if (res == null) {
        return; // cancelled
      }

      path = res.files.single.path;
      if (path == null) {
        return;
      }
    }

    final file = File(path);

    setState(() {
      _isUploading = true;
    });

    try {
      // upload using TenantService; TenantService.uploadTenantDocument returns Firestore document path (e.g. 'tenants/{tenantId}/documents/{docId}')
      final ref = await widget.tenantService.uploadTenantDocument(
        widget.tenantId,
        file,
      );
      setState(() {
        _uploadedUrl = ref;
      });
      widget.onUploaded(ref);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload gagal: $e')));
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
