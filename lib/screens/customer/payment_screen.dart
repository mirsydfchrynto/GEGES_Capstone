// lib/screens/customer/payment_screen.dart
import 'dart:io';
import 'dart:async';
import 'dart:convert'; // Untuk konversi Base64
// Untuk konversi bytes

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/models/queue.dart';

class PaymentScreen extends StatefulWidget {
  final String orderId;
  final int totalPrice;

  final String? barbershopId;
  final String? barbermanId;
  final DateTime? bookingTime;
  final List<String>? serviceIds;
  final DateTime? paymentDeadline;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.totalPrice,
    this.barbershopId,
    this.barbermanId,
    this.bookingTime,
    this.serviceIds,
    this.paymentDeadline,
  });

  @override
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Theme
  static const Color kBrownAccent = Color(0xFFB9976E);
  static const Color kSurface = Color(0xFF1B1B1B);
  static const Color kCardColor = Color(0xFF2C2C2C);
  static const Color kDisabledText = Colors.white54;
  static const Color kTextDark = Color(0xFF1B1B1B);

  // Timer & State
  Timer? _timer;
  Duration _timeRemaining = const Duration(minutes: 9, seconds: 59);

  // Image & upload
  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;
  String? _pickedBase64; // caching base64 for preview
  bool _isSubmitting = false;
  bool _hasUploadedProof = false;
  String? _resolvedQueueId;

  // Cache data dummy order detail
  final Map<String, int> _dummyOrderDetails = {
    'Signature Haircut': 40000,
    'Hot Towel': 12000,
    'Service Fee': 2500,
  };

  final QueueService _queueService = QueueService();

  @override
  void initState() {
    super.initState();
    _initTimeRemaining();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialQueueState();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialQueueState() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Try to get by document ID first (orderId may be queue id)
      final byId = await _queueService.getQueueById(widget.orderId);
      if (byId != null && byId.customerId == user.uid) {
        setState(() {
          _resolvedQueueId = byId.id;
          _hasUploadedProof = (byId.paymentProofBase64 != null && byId.paymentProofBase64!.isNotEmpty);
        });
        return;
      }

      // Fallback: search by order_id field for this user
      final qs = await FirebaseFirestore.instance
          .collection('queues')
          .where('order_id', isEqualTo: widget.orderId)
          .where('customer_id', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (qs.docs.isNotEmpty) {
        final q = Queue.fromFirestore(qs.docs.first);
        setState(() {
          _resolvedQueueId = q.id;
          _hasUploadedProof = (q.paymentProofBase64 != null && q.paymentProofBase64!.isNotEmpty);
        });
      }
    } catch (e) {
      debugPrint('Failed to load initial queue state: $e');
    }
  }

  // --- Timer logic ---
  void _initTimeRemaining() {
    if (widget.paymentDeadline != null) {
      final rem = widget.paymentDeadline!.difference(DateTime.now());
      _timeRemaining = rem.isNegative ? Duration.zero : rem;
    } else {
      // fallback to default 10 minutes window
      _timeRemaining = const Duration(minutes: 9, seconds: 59);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining.inSeconds <= 0) {
        timer.cancel();
        if (mounted) setState(() {});
        // when timer expires, attempt to auto-cancel the specific queue if needed
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _handleExpiry();
        });
      } else {
        if (mounted) {
          setState(() {
            _timeRemaining = _timeRemaining - const Duration(seconds: 1);
          });
        }
      }
    });
  }

  Future<void> _handleExpiry() async {
    try {
      if (_hasUploadedProof) return; // proof already uploaded, nothing to do
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // If we have a resolved queue id, check that queue specifically
      if (_resolvedQueueId != null) {
        final q = await _queueService.getQueueById(_resolvedQueueId!);
        if (q == null) return;
        // Only cancel if still awaiting payment and no proof
        if (q.paymentDeadline != null && DateTime.now().isAfter(q.paymentDeadline!.toDate())) {
          if ((q.paymentProofBase64 == null || q.paymentProofBase64!.isEmpty) && q.status.value == 'awaiting_payment') {
            await _queueService.cancelQueue(q.id, reason: 'Payment timeout', cancelledBy: 'system');
            if (mounted) {
              _showSnack('Waktu pembayaran habis. Pesanan dibatalkan otomatis.', isError: true);
            }
          }
        }
        return;
      }

      // fallback: cancel any awaiting_payment for this customer that expired
      await _queueService.cancelExpiredAwaitingPaymentQueuesForCustomer(uid);
    } catch (e) {
      debugPrint('Error handling expiry: $e');
    }
  }

  /// Atomic transaction: find existing queue by order_id or create new one with proof.
  /// Ensures proof is set and status is preserved (no regressions).
  Future<void> _submitPaymentProofTransaction(String userId, String base64Proof, Queue existingQueue) async {
    final firestore = FirebaseFirestore.instance;
    final orderIndexRef = firestore.collection('order_index').doc(widget.orderId);

    try {
      await firestore.runTransaction((tx) async {
        // Check order_index to find the queue id
        final idxSnap = await tx.get(orderIndexRef);
        DocumentReference<Map<String, dynamic>>? targetQueueRef;

        if (idxSnap.exists && idxSnap.data()?['queue_id'] != null) {
          // Existing queue — use it
          final queueId = idxSnap.data()!['queue_id'] as String;
          targetQueueRef = firestore.collection('queues').doc(queueId);

          // Verify ownership in transaction
          final qSnap = await tx.get(targetQueueRef);
          if (!qSnap.exists) {
            throw Exception('Queue referenced by order_index no longer exists');
          }
          final qData = qSnap.data();
          if (qData?['customer_id'] != userId) {
            throw Exception('Unauthorized: queue does not belong to current user');
          }

          // Update with proof, preserve status
          tx.update(targetQueueRef, {
            'payment_proof_base64': base64Proof,
            'payment_method': 'bank_transfer',
            'payment_amount': widget.totalPrice,
            'status': (qData?['status'] as String?) ?? existingQueue.status.value,
            'payment_submitted_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        } else {
          // No index yet — create queue + index atomically
          final newQueueRef = firestore.collection('queues').doc();
          targetQueueRef = newQueueRef;

          final queueData = {
            'barbershop_id': widget.barbershopId,
            'barberman_id': widget.barbermanId,
            'booking_time': widget.bookingTime != null ? Timestamp.fromDate(widget.bookingTime!) : Timestamp.now(),
            'service_ids': widget.serviceIds ?? [],
            'total_price': widget.totalPrice,
            'status': 'awaiting_payment',
            'request_status': 'approved',
            'payment_proof_base64': base64Proof,
            'payment_submitted_at': FieldValue.serverTimestamp(),
            'payment_method': 'bank_transfer',
            'payment_amount': widget.totalPrice,
            'order_id': widget.orderId,
            'customer_id': userId,
            'created_at': FieldValue.serverTimestamp(),
            'payment_deadline': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
          };

          // Create queue and index atomically
          tx.set(newQueueRef, queueData);
          tx.set(orderIndexRef, {
            'queue_id': newQueueRef.id,
            'created_at': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('Error in _submitPaymentProofTransaction: $e');
      rethrow;
    }
  }


  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "00:$minutes:$seconds";
  }

  String _formatCurrency(int amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0)
        .format(amount)
        .replaceAll(',', '.');
  }

  void _showSnack(String msg, {bool isError = false, bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
  backgroundColor: isError ? const Color(0xFFD32F2F) : (success ? kBrownAccent : kCardColor),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied to clipboard', success: true);
  }

  // --- Image Handling & Base64 Logic ---
  Future<bool> _ensurePermission(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted) return true;
    final result = await permission.request();
    return result.isGranted;
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: kBrownAccent),
                title: const Text('Photo Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  _pickFromSource(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: kBrownAccent),
                title: const Text('Camera', style: TextStyle(color: Colors.white)),
                onTap: () {
                  _pickFromSource(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromSource(ImageSource source) async {
    final permission = source == ImageSource.gallery ? Permission.photos : Permission.camera;
    final ok = await _ensurePermission(permission);
    if (!ok) {
      _showSnack('${source == ImageSource.gallery ? 'Gallery' : 'Camera'} permission denied');
      return;
    }
    try {
      final XFile? f = await _picker.pickImage(source: source, maxWidth: 1000, imageQuality: 78);
      if (f == null) return;
      final file = File(f.path);
      setState(() {
        _pickedImage = file;
        _pickedBase64 = null; // will compute lazily when needed
      });
    } catch (e) {
      _showSnack('Gagal memilih gambar: $e', isError: true);
    }
  }

  Future<String> _convertImageToBase64(File file) async {
    final Uint8List bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _submitPaymentProof() async {
    if (_timeRemaining.inSeconds == 0) {
      _showSnack('Payment time expired', isError: true);
      return;
    }
    if (_pickedImage == null) {
      _showSnack('Pilih bukti pembayaran terlebih dahulu', isError: true);
      return;
    }
    if (_isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('User not authenticated. Please log in again.', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Validate ownership using QueueService method
      final queue = await _queueService.getQueueByIdForCustomer(widget.orderId, user.uid);
      if (queue == null) {
        _showSnack('Pesanan tidak ditemukan atau tidak milik Anda', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      // Check if payment already submitted
      if (queue.paymentProofBase64 != null && queue.paymentProofBase64!.isNotEmpty) {
        _showSnack('Bukti pembayaran sudah pernah diunggah', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      // Validate payment deadline
      if (queue.paymentDeadline != null && DateTime.now().isAfter(queue.paymentDeadline!.toDate())) {
        _showSnack('Waktu pembayaran sudah habis. Pesanan dibatalkan otomatis.', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      // compute base64 only once
      _pickedBase64 ??= await _convertImageToBase64(_pickedImage!);

      // simple safety check size:
      const int limit = 950000;
      if ((_pickedBase64?.length ?? 0) > limit) {
        throw Exception('Ukuran file terlalu besar. Silakan kompres atau crop gambar.');
      }

      // Use atomic transaction: find-or-create with proof in single TX
      await _submitPaymentProofTransaction(user.uid, _pickedBase64!, queue);

      if (mounted) {
        setState(() {
          _hasUploadedProof = true;
        });
        Navigator.of(context).pop(true);
      }
      _showSnack('Bukti pembayaran berhasil diunggah — menunggu konfirmasi admin.', success: true);
    } catch (e) {
      _showSnack('Gagal submit bukti: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- UI Components ---
  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildInfoField(String label, String value, bool withCopy, {VoidCallback? onCopy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: kDisabledText, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(value,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right),
                ),
                if (withCopy)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: InkWell(
                      onTap: onCopy,
                      child: const Icon(Icons.copy, color: kBrownAccent, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String step, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: kBrownAccent, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(step, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isTotal ? Colors.white : kDisabledText, fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(amount, style: TextStyle(color: isTotal ? kBrownAccent : Colors.white, fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildTimerCard() {
    final bool isExpired = _timeRemaining.inSeconds == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
  border: Border.all(color: isExpired ? const Color(0xFFD32F2F) : kBrownAccent, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(isExpired ? 'Payment Time Expired' : 'Complete payment within',
              style: const TextStyle(color: Colors.white, fontSize: 15)),
          Text(isExpired ? '00:00:00' : _formatDuration(_timeRemaining),
              style: TextStyle(
                  color: isExpired ? const Color(0xFFD32F2F) : kBrownAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTotalPaymentCard() {
    return _buildSectionCard(
      child: Column(
        children: [
          Text('Total Payment', style: TextStyle(color: kDisabledText, fontSize: 14)),
          const SizedBox(height: 8),
          Text(_formatCurrency(widget.totalPrice),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Order ID: ${widget.orderId}', style: TextStyle(color: kDisabledText, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBankDetailsCard() {
    const accountNumber = '87705955837';
    const accountName = 'FEBRIAN BARBERSHOP';
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.account_balance, color: kDisabledText, size: 28),
            SizedBox(width: 12),
            Text('Bank BCA\nBank Transfer', style: TextStyle(color: Colors.white, fontSize: 15, height: 1.3)),
          ]),
          const SizedBox(height: 20),
          _buildInfoField('Account Number', accountNumber, true, onCopy: () => _copyToClipboard(accountNumber)),
          _buildInfoField('Account Name', accountName, false),
          _buildInfoField('Transfer Amount (exact)', _formatCurrency(widget.totalPrice), true,
              onCopy: () => _copyToClipboard(widget.totalPrice.toString())),
          const SizedBox(height: 12),
          // QR placeholder (tidak wajib)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                // small placeholder box for QR
                Container(width: 72, height: 72, color: Colors.black26, child: const Icon(Icons.qr_code, color: Colors.white54)),
                const SizedBox(width: 12),
                Expanded(child: Text('Scan QR (jika tersedia) atau transfer manual ke rekening di atas', style: TextStyle(color: kDisabledText))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Transfer the exact amount to ensure faster verification.',
              style: TextStyle(color: kDisabledText, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return _buildSectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Payment Instructions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildInstructionStep('1', 'Buka aplikasi mobile banking atau ATM'),
        _buildInstructionStep('2', 'Pilih transfer ke rekening BCA di atas'),
        _buildInstructionStep('3', 'Masukkan nomor rekening & nama penerima'),
        _buildInstructionStep('4', 'Masukkan nominal yang sama persis (${_formatCurrency(widget.totalPrice)})'),
        _buildInstructionStep('5', 'Simpan screenshot atau foto bukti transfer lalu unggah di bagian Upload'),
      ]),
    );
  }

  Widget _buildOrderDetailsCard() {
    final int totalOrderDetails = _dummyOrderDetails.values.fold(0, (acc, item) => acc + item);

    return _buildSectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Order Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ..._dummyOrderDetails.entries.map((entry) => _buildDetailRow(entry.key, _formatCurrency(entry.value))),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(color: Colors.white24)),
        _buildDetailRow('Total', _formatCurrency(widget.totalPrice), isTotal: true),
        const SizedBox(height: 4),
        if (widget.totalPrice != totalOrderDetails)
          Text('Note: Total payment may include additional fees or taxes not itemized above.', style: TextStyle(color: kDisabledText, fontSize: 11)),
      ]),
    );
  }

  Widget _buildUploadCard() {
    final isExpired = _timeRemaining.inSeconds == 0;
    return _buildSectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Upload Payment Proof', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Upload screenshot/photo of the transfer receipt to speed up verification.', style: TextStyle(color: kDisabledText, fontSize: 13)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: (isExpired || _isSubmitting || _hasUploadedProof) ? null : _showPickOptions,
          child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
              child: _pickedImage == null
                  ? (_hasUploadedProof
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 42),
                          const SizedBox(height: 8),
                          const Text('Bukti pembayaran sudah diunggah', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 6),
                          Text('Jika ada masalah, hubungi admin.', style: TextStyle(color: kDisabledText, fontSize: 12)),
                        ]))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.upload_file_outlined, color: kBrownAccent, size: 42),
                          const SizedBox(height: 8),
                          Text(isExpired ? 'Time expired' : 'Tap to choose image (camera/gallery)', style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text('Format JPG/PNG. Crop to show transfer details.', style: TextStyle(color: kDisabledText, fontSize: 12)),
                        ]))
                  : Stack(children: [
                      Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_pickedImage!, fit: BoxFit.cover))),
                      Positioned(
                        right: 8, top: 8,
                        child: Row(children: [
                          InkWell(
                            onTap: _viewFullScreenPreview,
                            child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.remove_red_eye, color: Colors.white, size: 18)),
                          ),
                          const SizedBox(width: 8),
                          if (!_hasUploadedProof)
                            InkWell(
                              onTap: () => setState(() { _pickedImage = null; _pickedBase64 = null; }),
                              child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.close, color: Colors.white, size: 18)),
                            ),
                        ]),
                      ),
                      if (_isSubmitting)
                        Positioned.fill(
                          child: Container(
                            color: Color.fromRGBO(0, 0, 0, 0.45),
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: (_pickedImage == null || _hasUploadedProof) ? null : _viewFullScreenPreview,
              icon: const Icon(Icons.remove_red_eye),
              label: const Text('Preview'),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white12)),
            ),
          ),
        ]),
      ]),
    );
  }

  void _viewFullScreenPreview() {
    if (_pickedImage == null) return;
    showDialog(
      context: context,
      builder: (c) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(8),
            child: InteractiveViewer(
              child: Image.file(_pickedImage!, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBrownAccent, width: 1)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: kBrownAccent, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text('Please transfer the exact amount. If payment is not completed within the time limit, your order will be automatically cancelled.', style: TextStyle(color: kDisabledText, fontSize: 13, height: 1.4))),
      ]),
    );
  }

  Widget _buildActionButtons() {
    final isExpired = _timeRemaining.inSeconds == 0;
    final disable = isExpired || _isSubmitting || _hasUploadedProof;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ElevatedButton(
        onPressed: disable ? null : _submitPaymentProof,
        style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: kTextDark, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: Text(_hasUploadedProof ? 'Bukti Terunggah' : (_isSubmitting ? 'Processing...' : 'Submit Proof & Create Queue'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: kSurface,
        appBar: AppBar(
          title: const Text('Payment', style: TextStyle(color: Colors.white)),
          backgroundColor: kSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (!_isSubmitting) {
                Navigator.of(context).pop();
              } else {
                _showSnack('Mohon tunggu proses submit selesai.', isError: true);
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTimerCard(),
              const SizedBox(height: 16),
              _buildTotalPaymentCard(),
              _buildBankDetailsCard(),
              _buildInstructionsCard(),
              _buildOrderDetailsCard(),
              _buildUploadCard(),
              const SizedBox(height: 8),
              _buildWarningCard(),
              const SizedBox(height: 24),
              _buildActionButtons(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
