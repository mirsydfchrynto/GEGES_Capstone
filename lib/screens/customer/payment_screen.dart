// lib/screens/customer/payment_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/queue_service_contract.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';

// --- No-Op Service for Tenant Mode ---
class _NoOpQueueService implements QueueServiceContract {
  @override
  Future<int> cancelExpiredAwaitingPaymentQueuesForCustomer(String customerId) async => 0;
  @override
  Future<int> cancelExpiredWaitingQueuesForCustomer(String customerId) async => 0;
  @override
  Future<void> cancelQueue(String queueId, {String reason = '', String? cancelledBy}) async {}
  @override
  Future<Queue?> getQueueById(String id) async => null;
  @override
  Stream<Queue?> streamQueueById(String id) async* { yield null; }
  @override
  Future<Queue?> resolveQueueForCustomerByIdOrOrder(String idOrOrderId, String customerId) async => null;
  @override
  Future<void> submitPaymentProofForQueue({required String queueId, required String userId, required String base64Proof}) async {}
}

class PaymentScreen extends StatefulWidget {
  // Core Data
  final String orderId;
  final int totalPrice;
  
  // Context Data (Booking vs Tenant)
  final String? barbershopId;
  final String? barbermanId;
  final DateTime? bookingTime;
  final List<String>? serviceIds;
  final DateTime? paymentDeadline;
  
  // Tenant Specific
  final String? tenantId;
  final Future<void> Function({required String tenantId, required String base64, required String userId})? tenantPaymentHandler;
  final Future<void> Function({required String tenantId, required String userId, String? reason})? cancelTenantHandler;

  // Injection / Testing
  final QueueServiceContract? queueService;
  final String? testUserId;
  final ImagePicker? imagePicker;
  final bool disableTimer;
  final Future<void> Function()? submitProofHandler;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.totalPrice,
    this.barbershopId,
    this.barbermanId,
    this.bookingTime,
    this.serviceIds,
    this.paymentDeadline,
    this.tenantId,
    this.tenantPaymentHandler,
    this.cancelTenantHandler,
    this.queueService,
    this.testUserId,
    this.imagePicker,
    this.disableTimer = false,
    this.submitProofHandler,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Theme Constants
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kSurface = Color(0xFF0F0F0F);
  static const Color kCardBg = Color(0xFF1A1A1A);
  static const Color kTextSecondary = Colors.white54;

  // Logic Controllers
  late final QueueServiceContract _queueService;
  late final ImagePicker _picker;
  Timer? _timer;
  StreamSubscription<Queue?>? _queueSub;

  // State
  Duration _timeRemaining = const Duration(minutes: 15);
  bool _isLoading = true;
  bool _isSubmitting = false;
  File? _pickedImage;
  String? _resolvedQueueId;
  bool _hasUploadedProof = false;
  String? _paymentStatus; // 'awaiting', 'pending_verification', 'success', 'expired', 'rejected'

  // Dynamic Data
  Map<String, int> _itemizedBill = {}; // Service name -> Price

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    _queueService = widget.queueService ?? (widget.tenantId != null ? _NoOpQueueService() : QueueService());
    _initTimer();
    _loadInitialData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _queueSub?.cancel();
    super.dispose();
  }

  void _initTimer() {
    if (widget.paymentDeadline != null) {
      final diff = widget.paymentDeadline!.difference(DateTime.now());
      _timeRemaining = diff.isNegative ? Duration.zero : diff;
    }
    if (!widget.disableTimer) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_timeRemaining.inSeconds > 0) {
            _timeRemaining -= const Duration(seconds: 1);
          } else {
            timer.cancel();
            _paymentStatus = 'expired';
          }
        });
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    // 1. Load Bill Details
    if (widget.tenantId != null) {
      _itemizedBill = {'Registration Fee': widget.totalPrice};
      _paymentStatus = 'awaiting';
    } else {
      // Logic for Booking Flow
      if (widget.serviceIds != null && widget.serviceIds!.isNotEmpty) {
        try {
          final shopService = BarbershopService();
          final services = await shopService.getServicesByIds(widget.serviceIds!);
          
          int servicesTotal = 0;
          Map<String, int> tempBill = {};
          
          for (var s in services) {
            tempBill[s.name] = s.price.toInt();
            servicesTotal += s.price.toInt();
          }

          // Check for extra fees (Selection Fee / Admin Fee)
          if (widget.totalPrice > servicesTotal) {
             final diff = widget.totalPrice - servicesTotal;
             tempBill['Biaya Reservasi / Barber'] = diff;
          }

          if (mounted) {
            setState(() => _itemizedBill = tempBill);
          }
        } catch (e) {
          debugPrint("Error fetching services: $e");
          // Fallback if fetch fails
           _itemizedBill = {'Total Layanan': widget.totalPrice};
        }
      } else {
        _itemizedBill = {'Barber Service': widget.totalPrice};
      }
    }

    // 2. Resolve Queue Status (Real-time)
    final userId = widget.testUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId != null && widget.tenantId == null) {
      try {
        final q = await _queueService.resolveQueueForCustomerByIdOrOrder(widget.orderId, userId);
        if (q != null) {
          _resolvedQueueId = q.id;
          _listenToQueue(q.id);
        } else {
           debugPrint("PaymentScreen: Queue not found for order ${widget.orderId}");
        }
      } catch (e) {
        debugPrint("PaymentScreen Error: $e");
      }
    }

    setState(() => _isLoading = false);
  }

  void _listenToQueue(String queueId) {
    _queueSub?.cancel();
    _queueSub = _queueService.streamQueueById(queueId).listen((q) {
      if (!mounted || q == null) return;
      
      String newStatus = 'awaiting';
      bool proofExists = (q.paymentProofBase64 != null && q.paymentProofBase64!.isNotEmpty) ||
                         (q.paymentProofUrl != null && q.paymentProofUrl!.isNotEmpty);

      if (q.status == QueueStatus.booked || q.status == QueueStatus.ongoing) {
        newStatus = 'success';
      } else if (q.status == QueueStatus.cancelled) {
        if (q.rejectionReason != null) {
          newStatus = 'rejected';
        } else {
          newStatus = 'expired';
        }
      } else if (proofExists) {
        newStatus = 'pending_verification';
      }

      // Update timer from server truth
      if (q.paymentDeadline != null && newStatus == 'awaiting') {
         final diff = q.paymentDeadline!.toDate().difference(DateTime.now());
         _timeRemaining = diff.isNegative ? Duration.zero : diff;
      }

      setState(() {
        _hasUploadedProof = proofExists;
        _paymentStatus = newStatus;
      });

      if (newStatus == 'success') {
        _timer?.cancel();
      }
    });
  }

  // --- ACTIONS ---

  Future<void> _pickImage() async {
    if (_hasUploadedProof || _isSubmitting) return;
    
    // Permission handling for real devices
    if (widget.imagePicker == null) {
      if (Platform.isAndroid || Platform.isIOS) {
         // Simple check, in production use permission_handler properly
      }
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() => _pickedImage = File(image.path));
      }
    } catch (e) {
      _showSnack("Gagal mengambil gambar: $e", isError: true);
    }
  }

  Future<void> _submitProof() async {
    if (_pickedImage == null && widget.submitProofHandler == null) {
      _showSnack("Mohon pilih bukti transfer terlebih dahulu.", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Test Handler
      if (widget.submitProofHandler != null) {
        await widget.submitProofHandler!();
        if (mounted) {
           _showSnack("Bukti terkirim! Admin akan memverifikasi pendaftaran Anda.", success: true);
           // Do not pop here if we want to show 'pending_verification' state
           // But since there's no stream for tenant mode, we might want to stay or pop
           if (widget.tenantId != null) {
             // For tenant, we stay and show pending status or pop? 
             // Logic in TenantContinueScreen pops. Here we should probably pop or update UI.
             // Let's pop to be consistent with TenantContinueScreen logic.
             Navigator.pop(context);
           }
        }
        return;
      }

      final userId = widget.testUserId ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("User not logged in");

      final bytes = await _pickedImage!.readAsBytes();
      final base64Img = base64Encode(bytes);

      if (widget.tenantId != null && widget.tenantPaymentHandler != null) {
        await widget.tenantPaymentHandler!(
          tenantId: widget.tenantId!,
          base64: base64Img,
          userId: userId
        );
         _showSnack("Bukti terkirim! Admin akan memverifikasi pendaftaran Anda.", success: true);
         // For tenant, navigate back or update state?
         // Usually we pop back to dashboard or show success.
         // Let's just pop to avoid stuck state.
         if (mounted) Navigator.pop(context);
      } else if (_resolvedQueueId != null) {
        await _queueService.submitPaymentProofForQueue(
          queueId: _resolvedQueueId!, 
          userId: userId, 
          base64Proof: base64Img
        );
        _showSnack("Bukti terkirim! Mohon tunggu verifikasi admin.", success: true);
        // Do NOT pop here, let the stream update the UI to 'pending_verification'
      }

    } catch (e) {
      _showSnack("Gagal upload: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false, bool success = false}) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: success || isError ? Colors.white : Colors.black)),
      backgroundColor: isError ? Colors.redAccent : (success ? Colors.green : Colors.white),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _handleBack(BuildContext context) {
    if (_isSubmitting) {
      _showSnack("Mohon tunggu proses selesai.", isError: true);
      return;
    }
    
    final l10n = AppLocalizations.of(context)!;
    if (widget.tenantId != null && _paymentStatus == 'awaiting') {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l10n.registrationIncompleteTitle),
          content: Text(l10n.registrationIncompleteMsg),
          actions: [
            TextButton(child: Text(l10n.btnCancelExit), onPressed: () => Navigator.pop(c)),
            TextButton(child: Text(l10n.btnExitSaveDraft), onPressed: () {
              Navigator.pop(c);
              Navigator.pop(context);
            }),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: kSurface, body: Center(child: CircularProgressIndicator(color: kBrownAccent)));
    }

    if (_paymentStatus == 'success') {
      return _buildSuccessScreen();
    }

    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_isSubmitting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSubmitting) {
          _showSnack("Mohon tunggu proses selesai.", isError: true);
        }
      },
      child: Scaffold(
        backgroundColor: kSurface,
        appBar: AppBar(
          backgroundColor: kSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white), 
            onPressed: () => _handleBack(context)
          ),
          title: Text(l10n.paymentTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildTimerHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOrderSummary(),
                    const SizedBox(height: 20),
                    _buildPaymentMethods(),
                    const SizedBox(height: 20),
                    _buildUploadSection(),
                    const SizedBox(height: 20),
                    if (_paymentStatus == 'pending_verification')
                      _buildStatusBanner(l10n.verifying, Icons.hourglass_top, Colors.orange)
                    else if (_paymentStatus == 'rejected')
                      _buildStatusBanner(l10n.paymentRejected, Icons.error_outline, Colors.red)
                    else if (_paymentStatus == 'expired')
                      _buildStatusBanner(l10n.timeOut, Icons.timer_off, Colors.grey),
                  ],
                ),
              ),
            ),
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerHeader() {
    bool isUrgent = _timeRemaining.inMinutes < 5;
    return Container(
      width: double.infinity,
      color: isUrgent ? Colors.red.withValues(alpha:0.1) : kCardBg,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Text("Selesaikan pembayaran dalam", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            "${_timeRemaining.inMinutes.toString().padLeft(2,'0')}:${(_timeRemaining.inSeconds % 60).toString().padLeft(2,'0')}",
            style: TextStyle(
              color: isUrgent ? Colors.redAccent : kBrownAccent,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.totalBill, style: const TextStyle(color: Colors.white54)),
              Text("#${widget.orderId}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(widget.totalPrice),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          ..._itemizedBill.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: const TextStyle(color: Colors.white70)),
                Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(e.value), style: const TextStyle(color: Colors.white)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final l10n = AppLocalizations.of(context)!;
    const accNumber = "87705955837";
    const accName = "FEBRIAN BARBERSHOP";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.transferTo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBrownAccent.withValues(alpha:0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: const Text("BCA", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Bank Central Asia", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(accName, style: TextStyle(color: kTextSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(accNumber, style: TextStyle(color: kBrownAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(const ClipboardData(text: accNumber));
                            _showSnack("No. Rekening disalin!", success: true);
                          },
                          child: const Icon(Icons.copy, size: 16, color: kBrownAccent)
                        )
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadSection() {
    final l10n = AppLocalizations.of(context)!;
    bool isLocked = _paymentStatus != 'awaiting'; 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.paymentProof, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        InkWell(
          onTap: isLocked ? null : _pickImage,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12, style: BorderStyle.solid),
              image: _pickedImage != null 
                ? DecorationImage(image: FileImage(_pickedImage!), fit: BoxFit.cover, opacity: 0.5)
                : null
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_pickedImage == null)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 48, color: isLocked ? Colors.grey : kBrownAccent),
                      const SizedBox(height: 12),
                      Text(
                        isLocked ? l10n.uploadLocked : l10n.tapToUpload, 
                        style: const TextStyle(color: Colors.white70)
                      ),
                    ],
                  ),
                if (_pickedImage != null)
                   const Icon(Icons.check_circle, color: kBrownAccent, size: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    final l10n = AppLocalizations.of(context)!;
    bool isLocked = _paymentStatus != 'awaiting';
    String btnText = l10n.sendProof;
    if (_isSubmitting) btnText = l10n.sending;
    if (_paymentStatus == 'pending_verification') btnText = l10n.verificationPending;
    if (_paymentStatus == 'expired') btnText = l10n.timeOut;
    if (_paymentStatus == 'success') btnText = "Berhasil!";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha:0.05))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (isLocked || _isSubmitting) ? null : _submitProof,
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrownAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                disabledBackgroundColor: Colors.white10,
                disabledForegroundColor: Colors.white24,
              ),
              child: _isSubmitting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                : Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          
          if (widget.tenantId != null) ...[
             const SizedBox(height: 12),
             TextButton(
               onPressed: _isSubmitting ? null : () {
                 if (widget.cancelTenantHandler != null) {
                    widget.cancelTenantHandler!(tenantId: widget.tenantId!, userId: widget.testUserId ?? '');
                 }
                 Navigator.pop(context);
               },
               child: const Text("Batalkan Pendaftaran", style: TextStyle(color: Colors.redAccent)),
             )
          ]
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: kSurface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified, size: 80, color: kBrownAccent),
              const SizedBox(height: 24),
              Text(l10n.paymentAccepted, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(l10n.paymentSuccessDesc, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kBrownAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n.backToHome, style: const TextStyle(color: kBrownAccent, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}