// lib/screens/admin/cancellation_requests_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;

class CancellationRequestsScreen extends StatefulWidget {
  const CancellationRequestsScreen({super.key});
  @override
  State<CancellationRequestsScreen> createState() => _CancellationRequestsScreenState();
}

class _CancellationRequestsScreenState extends State<CancellationRequestsScreen> {
  final QueueService _queueService = QueueService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _cache = {};

  Future<String> _getCustomerName(String id) async {
    if (_cache.containsKey('c_$id')) return _cache['c_$id']!;
    try {
      final doc = await _firestore.collection('users').doc(id).get();
      final name = doc.data()?['name'] ?? 'Customer';
      _cache['c_$id'] = name;
      return name;
    } catch (_) {
      return 'Customer';
    }
  }

  Future<String> _getBarbershopName(String id) async {
    if (_cache.containsKey('bs_$id')) return _cache['bs_$id']!;
    try {
      final doc = await _firestore.collection('barbershops').doc(id).get();
      final name = doc.data()?['name'] ?? 'Barbershop';
      _cache['bs_$id'] = name;
      return name;
    } catch (_) {
      return 'Barbershop';
    }
  }

  Future<String> _getBarbershopImage(String id) async {
    const defaultImage = 'https://cdn-icons-png.flaticon.com/512/706/706830.png';
    if (_cache.containsKey('img_$id')) return _cache['img_$id']!;
    try {
      final doc = await _firestore.collection('barbershops').doc(id).get();
      final image = doc.data()?['imageUrl'] ?? defaultImage;
      _cache['img_$id'] = image;
      return image;
    } catch (_) {
      return defaultImage;
    }
  }

  Future<Map<String, dynamic>> _fetchDetails(Queue q) async {
    final results = await Future.wait([_getCustomerName(q.customerId), _getBarbershopName(q.barbershopId), _getBarbershopImage(q.barbershopId)]);
    return {'customer': results[0], 'shop': results[1], 'image': results[2]};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(backgroundColor: kSurface, foregroundColor: Colors.white, elevation: 0, title: const Text('Cancellation Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22))),
      body: StreamBuilder<List<Queue>>(
        stream: _queueService.streamAllQueues(statusFilter: ['cancellation_requested']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kBrownAccent));
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: kTextGrey, size: 60), SizedBox(height: 16), Text('No cancellation requests', style: TextStyle(color: kTextGrey))]));
          }
          requests.sort((a, b) => b.bookingTime.compareTo(a.bookingTime));
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: requests.length, itemBuilder: (context, i) => _buildCard(context, requests[i]));
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, Queue q) {
    final refundAmount = (q.totalPrice ?? 0) * 0.9;
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchDetails(q),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(height: 160, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: kDarkGrey, borderRadius: BorderRadius.circular(12)), child: const Center(child: CircularProgressIndicator(color: kBrownAccent)));
        }
        final d = snapshot.data!;
        return GestureDetector(
          onTap: () => _showDetail(context, q, d, refundAmount),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: kDarkGrey, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stack(children: [
                Container(height: 130, width: double.infinity, color: Colors.grey[900], child: CachedNetworkImage(imageUrl: d['image'], fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.storefront, color: kTextGrey))),
                Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(16)), child: const Text('CANCELLATION', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold))))
              ]),
              Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['shop'], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [const Icon(Icons.person, size: 11, color: kTextGrey), const SizedBox(width: 3), Expanded(child: Text(d['customer'], style: const TextStyle(color: kTextGrey, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                const SizedBox(height: 2),
                Row(children: [const Icon(Icons.info_outline, size: 11, color: Colors.amber), const SizedBox(width: 3), Expanded(child: Text(q.rejectionReason ?? 'No reason', style: const TextStyle(color: Colors.amber, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                const SizedBox(height: 2),
                Row(children: [const Icon(Icons.attach_money, size: 11, color: Colors.orange), const SizedBox(width: 3), Text('Refund: ${NumberFormat.currency(locale: "id_ID", symbol: "Rp ", decimalDigits: 0).format(refundAmount)}', style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold))])
              ]))
            ]),
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, Queue q, Map<String, dynamic> d, double refundAmount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kDarkGrey,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Container(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Cancellation Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), GestureDetector(onTap: () => Navigator.pop(c), child: const Icon(Icons.close, color: Colors.white))]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _row('Status', 'CANCELLATION PENDING', Colors.amber),
                _row('Customer', d['customer']),
                _row('Shop', d['shop']),
                _row('Booking Date', _formatTs(q.bookingTime)),
                _row('Original Price', NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(q.totalPrice ?? 0)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Refund Details', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Original Price', style: TextStyle(color: kTextGrey, fontSize: 10)), Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(q.totalPrice ?? 0), style: const TextStyle(color: Colors.white, fontSize: 10))]),
                    const SizedBox(height: 2),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Deduction (10%)', style: TextStyle(color: kTextGrey, fontSize: 10)), Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format((q.totalPrice ?? 0) * 0.1), style: const TextStyle(color: Colors.red, fontSize: 10))]),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(color: Colors.white24, height: 1)),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Refund Amount', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)), Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(refundAmount), style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold))]),
                  ]),
                ),
                const SizedBox(height: 8),
                const Text('Cancellation Reason:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(q.rejectionReason ?? 'No reason', style: const TextStyle(color: Colors.white, fontSize: 11), maxLines: 3),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final navigator = Navigator.of(c);
                    final messenger = ScaffoldMessenger.of(c);
                    try {
                      // show loading
                      showDialog(
                        context: c,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                      await _queueService.adminRejectCancellation(q.id);
                      // close loading then bottom sheet
                      Navigator.of(c).pop(); // close loading dialog
                      navigator.pop(); // close bottom sheet
                      messenger.showSnackBar(const SnackBar(content: Text('Cancellation request rejected'), backgroundColor: Colors.red));
                    } catch (e) {
                      // ensure loading closed
                      try {
                        Navigator.of(c).pop();
                      } catch (_) {}
                      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size.fromHeight(44)),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(c);
                    try {
                      final picked = await showModalBottomSheet<XFile?>(
                        context: c,
                        builder: (ctx) => _ApproveWithProofSheet(),
                      );

                      String? base64Proof;
                      if (picked != null) {
                        // show progress for encoding
                        showDialog(
                          context: c,
                          barrierDismissible: false,
                          builder: (_) => const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text('Processing proof...', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        );
                        final bytes = await picked.readAsBytes();
                        base64Proof = base64Encode(bytes);
                        // close progress
                        Navigator.of(c).pop();
                      }

                      // show loading for approval
                      showDialog(
                        context: c,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );

                      await _queueService.adminApproveCancellation(q.id, refundProofBase64: base64Proof);

                      // close loading then bottom sheet
                      Navigator.of(c).pop(); // close loading
                      Navigator.of(c).pop(); // close bottom sheet
                      messenger.showSnackBar(const SnackBar(content: Text('Refund approved'), backgroundColor: Colors.green));
                    } catch (e) {
                      try {
                        Navigator.of(c).pop();
                      } catch (_) {}
                      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(44)),
                  child: const Text('Approve'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _row(String label, String val, [Color? color]) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: kTextGrey, fontSize: 12)), Text(val, style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w600))]));
  }

  String _formatTs(Timestamp ts) => DateFormat('EEE d MMM HH:mm').format(ts.toDate());
}

// Modal sheet: allow admin to pick an image (camera/gallery) and confirm
class _ApproveWithProofSheet extends StatefulWidget {
  @override
  State<_ApproveWithProofSheet> createState() => _ApproveWithProofSheetState();
}

class _ApproveWithProofSheetState extends State<_ApproveWithProofSheet> {
  XFile? _picked;
  String? _errorMsg;
  final ImagePicker _picker = ImagePicker();
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const List<String> allowedFormats = ['jpg', 'jpeg', 'png'];

  Future<void> _pick(ImageSource src) async {
    try {
      final XFile? file = await _picker.pickImage(source: src, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
      if (file != null) {
        // Validate file size and format
        final fileSize = await file.length();
        final fileName = file.name.toLowerCase();
        final fileExt = fileName.split('.').last;

        if (fileSize > maxFileSizeBytes) {
          setState(() => _errorMsg = 'File terlalu besar (max 5 MB). Ukuran: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
          return;
        }

        if (!allowedFormats.contains(fileExt)) {
          setState(() => _errorMsg = 'Format tidak didukung. Pilih JPG atau PNG.');
          return;
        }

        setState(() {
          _picked = file;
          _errorMsg = null;
        });
      }
    } catch (e) {
      setState(() => _errorMsg = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Upload Bukti Refund (opsional)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        (_picked != null)
            ? Column(children: [
                SizedBox(height: 180, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_picked!.path), fit: BoxFit.cover))),
                const SizedBox(height: 8),
                FutureBuilder<int>(
                  future: _picked!.length(),
                  builder: (ctx, snap) {
                    final sizeStr = snap.hasData ? '${(snap.data! / 1024).toStringAsFixed(1)} KB' : 'Loading...';
                    return Text('Ukuran: $sizeStr', style: const TextStyle(color: Colors.grey, fontSize: 11));
                  },
                ),
              ])
            : const SizedBox(height: 120, child: Center(child: Icon(Icons.image, color: Colors.white24, size: 40))),
        const SizedBox(height: 12),
        if (_errorMsg != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.photo),
              label: const Text('Galeri'),
              onPressed: () => _pick(ImageSource.gallery),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
              onPressed: () => _pick(ImageSource.camera),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Skip'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_picked);
              },
              child: const Text('Confirm'),
            ),
          ),
        ])
      ]),
    );
  }
}
