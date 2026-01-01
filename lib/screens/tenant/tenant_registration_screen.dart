import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/widgets/document_upload_widget.dart';
import 'package:geges_smartbarber/screens/legal/terms_page.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';

class TenantRegistrationScreen extends StatefulWidget {
  final TenantService? tenantService;
  final String? currentUserId;
  final Future<String?> Function()? filePicker;
  final bool initialAcceptedTerms;
  final String? initialCompanyDocPath;
  final String? initialTaxDocPath;

  final Future<void> Function(String tenantId)? testSubmitProofHandler;

  const TenantRegistrationScreen({
    super.key,
    this.tenantService,
    this.currentUserId,
    this.filePicker,
    this.initialAcceptedTerms = false,
    this.initialCompanyDocPath,
    this.initialTaxDocPath,
    this.testSubmitProofHandler,
  });

  @override
  State<TenantRegistrationScreen> createState() =>
      _TenantRegistrationScreenState();
}

class _TenantRegistrationScreenState extends State<TenantRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _ownerEmailCtrl = TextEditingController();
  final _ownerPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();

  String _plan = 'monthly'; // monthly/yearly
  bool _submitting = false;

  // New: terms acceptance and pre-uploaded documents
  bool _acceptedTerms = false;
  File? _companyDocFile;
  File? _taxDocFile;

  @override
  void initState() {
    super.initState();
    _acceptedTerms = widget.initialAcceptedTerms;
    if (widget.initialCompanyDocPath != null) {
      _companyDocFile = File(widget.initialCompanyDocPath!);
    }
    if (widget.initialTaxDocPath != null) {
      _taxDocFile = File(widget.initialTaxDocPath!);
    }
    // Auto-check for existing pending registration
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingRegistration());
  }

  Future<void> _checkPendingRegistration() async {
    final userId =
        widget.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final fs = _tenantService.firestore;
      final existingQ = await fs
          .collection('tenants')
          .where('owner_uid', isEqualTo: userId)
          .where('status', whereIn: [
            'pending_payment',
            'awaiting_payment',
            'waiting_proof',
            'payment_submitted',
          ])
          .get();

      if (existingQ.docs.isNotEmpty && mounted) {
        // Sort by newest first
        final docs = existingQ.docs.toList();
        docs.sort((a, b) {
          final aTs =
              (a.data()['created_at'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTs =
              (b.data()['created_at'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTs.compareTo(aTs);
        });

        final doc = docs.first;
        final data = doc.data();
        final status = data['status'] as String?;
        
        // Cek data pembayaran di dalam map 'payment'
        final paymentData = data['payment'] as Map<String, dynamic>?;
        final verificationStatus = paymentData?['verificationStatus'] as String?;
        final hasProof = (paymentData?['payment_proof_base64'] != null && paymentData!['payment_proof_base64'].toString().isNotEmpty) ||
                         (paymentData?['proofUrl'] != null && paymentData!['proofUrl'].toString().isNotEmpty);

        // KONDISI 1: Sudah Bayar, Menunggu Verifikasi Admin
        // Jangan suruh bayar lagi!
        if (status == 'waiting_proof' || status == 'payment_submitted' || hasProof || verificationStatus == 'pending') {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Pendaftaran Sedang Diproses'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Anda sudah mengirimkan bukti pembayaran.'),
                  const SizedBox(height: 8),
                  const Text('Status: Menunggu Verifikasi Admin'),
                  const SizedBox(height: 8),
                  const Text('Mohon cek berkala di menu My Orders, untuk update status.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // Tutup dialog
                    Navigator.of(context).pop(); // Keluar dari screen registrasi
                  }, 
                  child: const Text('Tutup'),
                ),
              ],
            ),
          );
          return;
        }

        // KONDISI 2: Belum Bayar (Resume)
        // Ask user to resume
        final resume = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Lanjutkan Pendaftaran?'),
                content: const Text(
                  'Anda memiliki pendaftaran yang belum selesai (menunggu pembayaran). Ingin melanjutkannya?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Buat Baru'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Lanjutkan Bayar'),
                  ),
                ],
              ),
        );

        if (resume == true && mounted) {
          final invoice = data['invoice'] as Map<String, dynamic>?;
          final amount =
              invoice?['amount'] as int? ??
              data['registration_fee'] as int? ??
              _price;
          final deadline =
              (invoice?['payment_deadline'] as Timestamp?)?.toDate() ??
              DateTime.now().add(const Duration(hours: 1));

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder:
                  (_) => PaymentScreen(
                    orderId: doc.id,
                    totalPrice: amount,
                    tenantId: doc.id,
                    tenantPaymentHandler:
                        ({
                          required String tenantId,
                          required String base64,
                          required String userId,
                        }) async {
                          await _tenantService.submitRegistrationPayment(
                            tenantId: tenantId,
                            proofBase64: base64,
                            userId: userId,
                          );
                        },
                    cancelTenantHandler:
                        ({
                          required String tenantId,
                          required String userId,
                          String? reason,
                        }) async {
                          await _tenantService.cancelRegistrationByOwner(
                            tenantId: tenantId,
                            userId: userId,
                            reason: reason,
                          );
                        },
                    disableTimer: false,
                    paymentDeadline: deadline,
                    testUserId: widget.currentUserId,
                    submitProofHandler:
                        widget.testSubmitProofHandler != null
                            ? () => widget.testSubmitProofHandler!(doc.id)
                            : null,
                  ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking pending registration: $e');
    }
  }

  TenantService get _tenantService => widget.tenantService ?? TenantService();

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _legalNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerEmailCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _taxIdCtrl.dispose();
    super.dispose();
  }

  int get _price => _plan == 'monthly' ? 300000 : 3000000;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final accepted = _acceptedTerms || widget.initialAcceptedTerms;
    if (!accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Anda harus menyetujui Perjanjian Tenant sebelum melanjutkan',
          ),
        ),
      );
      return;
    }

    final userId = widget.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda harus login untuk mendaftar sebagai tenant'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Before creating a new tenant, check if a pending registration already exists for this user
      // If found, we must cancel it or reuse it. Since the user chose to "Buat Baru" (implied by passing the dialog check),
      // we should effectively archive/cancel the old one to avoid clutter.
      final fs = _tenantService.firestore;
      final existingQ = await fs
          .collection('tenants')
          .where('owner_uid', isEqualTo: userId)
          .where(
            'status',
            whereIn: ['pending_payment', 'awaiting_payment', 'waiting_proof'],
          )
          .get();

      for (var doc in existingQ.docs) {
        // Auto-cancel old pending ones so we don't have duplicates
        await _tenantService.cancelRegistrationByOwner(
          tenantId: doc.id,
          userId: userId,
          reason: 'User started a new registration',
        );
      }

      final data = {
        'business_name': _businessNameCtrl.text.trim(),
        'legal_name': _legalNameCtrl.text.trim(),
        'owner_name': _ownerNameCtrl.text.trim(),
        'owner_email': _ownerEmailCtrl.text.trim(),
        'owner_phone': _ownerPhoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'tax_id': _taxIdCtrl.text.trim(),
        'plan': _plan,
        'registration_fee': _price,
        'owner_uid': userId,
        'status': 'awaiting_payment', // Fix: match MyBookingsScreen filter
        'accepted_terms': accepted,
      };

      final tenantId = await _tenantService.createTenantApplication(data);

      // If user selected files earlier, upload them now and attach references to tenant doc
      if (_companyDocFile != null) {
        final ref = await _tenantService.uploadTenantDocument(
          tenantId,
          _companyDocFile!,
          filename: 'company_doc_${DateTime.now().millisecondsSinceEpoch}',
        );
        await _tenantService.updateTenantApplication(tenantId, {
          'company_doc_ref': ref,
        });
      }
      if (_taxDocFile != null) {
        final ref = await _tenantService.uploadTenantDocument(
          tenantId,
          _taxDocFile!,
          filename: 'tax_doc_${DateTime.now().millisecondsSinceEpoch}',
        );
        await _tenantService.updateTenantApplication(tenantId, {
          'tax_doc_ref': ref,
        });
      }

      // Create a registration invoice entry (simple structure) using the tenant service so tests' firestore is used
      await _tenantService.updateTenantApplication(tenantId, {
        'invoice_id': 'REG-${DateTime.now().millisecondsSinceEpoch}',
        'invoice': {
          'amount': _price,
          'currency': 'IDR',
          'status': 'waiting_proof',
          'created_at': Timestamp.now(),
          'payment_deadline': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 1)),
          ),
        },
      });

      // Navigate directly to Payment screen so user sees detailed payment instructions
      // and can upload proof in one flow (professional UX).
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            orderId:
                tenantId, // using tenantId as identifier; PaymentScreen checks tenantId to switch mode
            totalPrice: _price,
            tenantId: tenantId,
            tenantPaymentHandler:
                ({
                  required String tenantId,
                  required String base64,
                  required String userId,
                }) async {
                  await _tenantService.submitRegistrationPayment(
                    tenantId: tenantId,
                    proofBase64: base64,
                    userId: userId,
                  );
                },
            cancelTenantHandler:
                ({
                  required String tenantId,
                  required String userId,
                  String? reason,
                }) async {
                  await _tenantService.cancelRegistrationByOwner(
                    tenantId: tenantId,
                    userId: userId,
                    reason: reason,
                  );
                },
            // For registration flow we enable the countdown (1 hour window)
            disableTimer: false,
            paymentDeadline: DateTime.now().add(const Duration(hours: 1)),
            testUserId: widget.currentUserId,
            submitProofHandler: widget.testSubmitProofHandler != null
                ? () => widget.testSubmitProofHandler!(tenantId)
                : null,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mendaftar: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pendaftaran Franchise / Tenant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _businessNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Bisnis (Barbershop)',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama bisnis wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _legalNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Legal Perusahaan',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerNameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Pemilik'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama pemilik wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerEmailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Pemilik (Google account)',
                ),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Email tidak valid'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerPhoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon Pemilik',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Alamat Lengkap'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _taxIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'NPWP / Tax ID (opsional)',
                ),
              ),

              // --- New: Terms acceptance & document selections placed at the top ---
              Card(
                color: const Color(0xFF1B1B1B), // dark card to match app theme
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Persetujuan & Dokumen (wajib)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptedTerms,
                            onChanged: (v) =>
                                setState(() => _acceptedTerms = v ?? false),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TermsPage(),
                                ),
                              ),
                              child: const Text(
                                'Saya telah membaca dan menyetujui Perjanjian Tenant dan Kebijakan Aplikasi (ketuk untuk baca)',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Unggah dokumen awal: Surat Izin Usaha Perdagangan (SIUP) & Nomor Pokok Wajib Pajak (NPWP). Ukuran maksimal ~900KB per file.',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB9976E),
                              ),
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                _companyDocFile == null
                                    ? 'Pilih Surat Izin Usaha Perdagangan (SIUP)'
                                    : 'Surat Izin Usaha Perdagangan (SIUP): ${_companyDocFile!.path.split('/').last}',
                                style: const TextStyle(color: Colors.black),
                              ),
                              onPressed: () async {
                                String? pickedPath;
                                if (widget.filePicker != null) {
                                  pickedPath = await widget.filePicker!.call();
                                } else {
                                  final res = await FilePicker.platform
                                      .pickFiles();
                                  if (res == null || res.files.single.path == null) {
                                    return;
                                  }
                                  pickedPath = res.files.single.path;
                                }
                                if (pickedPath == null) return;
                                final p = pickedPath;
                                setState(() => _companyDocFile = File(p));
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB9976E),
                              ),
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                _taxDocFile == null
                                    ? 'Pilih Nomor Pokok Wajib Pajak (NPWP)'
                                    : 'Nomor Pokok Wajib Pajak (NPWP): ${_taxDocFile!.path.split('/').last}',
                                style: const TextStyle(color: Colors.black),
                              ),
                              onPressed: () async {
                                String? pickedPath;
                                if (widget.filePicker != null) {
                                  pickedPath = await widget.filePicker!.call();
                                } else {
                                  final res = await FilePicker.platform
                                      .pickFiles();
                                  if (res == null || res.files.single.path == null) {
                                    return;
                                  }
                                  pickedPath = res.files.single.path;
                                }
                                if (pickedPath == null) return;
                                final p = pickedPath;
                                setState(() => _taxDocFile = File(p));
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Pilih Paket',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment(value: 'monthly', label: Text('Bulanan - Rp 300.000')),
                  ButtonSegment(value: 'yearly', label: Text('Tahunan - Rp 3.000.000 (promo)')),
                ],
                selected: <String>{_plan},
                onSelectionChanged: (Set<String> newSelection) => setState(() => _plan = newSelection.first),
              ),

              const SizedBox(height: 16),
              const Text(
                'Setelah menekan Daftar, Anda akan diarahkan ke halaman lanjutan untuk mengunggah dokumen dan bukti pembayaran.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: _submitting
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        child: Text('Daftar & Bayar ${_price.toString()}'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TenantContinueScreen extends StatefulWidget {
  final String tenantId;
  final int amount;

  /// Optional overrides for testing and dependency injection
  final TenantService? tenantService;
  final FirebaseFirestore? firestore;
  final Future<String?> Function()? filePicker;

  /// Optional handler used in tests to bypass file pickers and directly submit proof.
  final Future<void> Function()? submitProofHandler;

  const TenantContinueScreen({
    super.key,
    required this.tenantId,
    required this.amount,
    this.tenantService,
    this.firestore,
    this.filePicker,
    this.submitProofHandler,
  });

  @override
  State<TenantContinueScreen> createState() => _TenantContinueScreenState();
}

class _TenantContinueScreenState extends State<TenantContinueScreen> {
  TenantService get _tenantService => widget.tenantService ?? TenantService();
  FirebaseFirestore get _fs => widget.firestore ?? FirebaseFirestore.instance;
  bool _isSubmitting = false;

  Future<void> _submitPaymentProof(File proofFile) async {
    setState(() => _isSubmitting = true);
    try {
      // Convert to base64 and validate size (same safety limits as booking payment)
      debugPrint(
        'TenantContinueScreen: starting submitPaymentProof for ${widget.tenantId}',
      );
      final bytes = await proofFile.readAsBytes();
      debugPrint('TenantContinueScreen: read bytes length ${bytes.length}');
      final base64Proof = base64Encode(bytes);
      const int limit = 950000;
      if (base64Proof.length > limit) {
        throw Exception(
          'Ukuran file terlalu besar. Silakan kompres atau crop gambar.',
        );
      }

      String userId = 'unknown';
      try {
        userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      } catch (_) {
        // In tests FirebaseAuth may not be initialized; fallback to 'unknown'
      }

      debugPrint('TenantContinueScreen: calling submitRegistrationPayment');
      await _tenantService.submitRegistrationPayment(
        tenantId: widget.tenantId,
        proofBase64: base64Proof,
        userId: userId,
      );
      debugPrint('TenantContinueScreen: submitRegistrationPayment returned');

      // update invoice status
      await _fs.collection('tenants').doc(widget.tenantId).set({
        'invoice': {
          'status': 'payment_submitted',
          'submitted_at': Timestamp.now(),
        },
      }, SetOptions(merge: true));

      debugPrint('TenantContinueScreen: invoice updated in firestore');

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bukti pembayaran terkirim. Pendaftaran dan dokumen sedang diproses (maks. 1 minggu). Anda akan diberi tahu via email dan notifikasi aplikasi.',
          ),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('TenantContinueScreen: submitPaymentProof error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim bukti pembayaran: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lengkapi Pendaftaran')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DocumentUploadWidget(
              tenantId: widget.tenantId,
              tenantService: _tenantService,
              label: 'Surat Izin Usaha / SIUP',
              onUploaded: (ref) async {
                await _tenantService.updateTenantApplication(widget.tenantId, {
                  'company_doc_ref': ref,
                });
              },
            ),
            const SizedBox(height: 12),
            DocumentUploadWidget(
              tenantId: widget.tenantId,
              tenantService: _tenantService,
              label: 'NPWP / Dokumen Pajak',
              onUploaded: (ref) async {
                await _tenantService.updateTenantApplication(widget.tenantId, {
                  'tax_doc_ref': ref,
                });
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Pembayaran pendaftaran: Rp ${widget.amount}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      if (widget.submitProofHandler != null) {
                        setState(() => _isSubmitting = true);
                        try {
                          await widget.submitProofHandler!.call();
                        } finally {
                          if (mounted) setState(() => _isSubmitting = false);
                        }
                        return;
                      }

                      String? path;
                      if (widget.filePicker != null) {
                        path = await widget.filePicker!.call();
                        if (path == null) return;
                      } else {
                        final res = await FilePicker.platform.pickFiles();
                        if (res == null || res.files.single.path == null) {
                          return;
                        }
                        path = res.files.single.path!;
                      }

                      final file = File(path);
                      await _submitPaymentProof(file);
                    },
              icon: const Icon(Icons.upload_file),
              label: _isSubmitting
                  ? const Text('Mengirim...')
                  : const Text('Unggah Bukti Pembayaran'),
            ),
          ],
        ),
      ),
    );
  }
}
