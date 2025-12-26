import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dart:io';
import 'package:file_picker/file_picker.dart';

import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/widgets/document_upload_widget.dart';

class TenantRegistrationScreen extends StatefulWidget {
  const TenantRegistrationScreen({super.key});

  @override
  State<TenantRegistrationScreen> createState() => _TenantRegistrationScreenState();
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


  final TenantService _tenantService = TenantService();

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anda harus login untuk mendaftar sebagai tenant')));
      return;
    }

    setState(() => _submitting = true);

    try {
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
        'owner_uid': user.uid,
        'status': 'pending_payment',
      };

      final tenantId = await _tenantService.createTenantApplication(data);

      // Create a registration invoice entry (simple structure)
      await FirebaseFirestore.instance.collection('tenants').doc(tenantId).set({
        'invoice': {
          'amount': _price,
          'currency': 'IDR',
          'status': 'waiting_proof',
          'created_at': Timestamp.now(),
        }
      }, SetOptions(merge: true));

      // Navigate to step 2: upload documents & submit payment using real tenantId
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TenantContinueScreen(tenantId: tenantId, amount: _price),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mendaftar: $e')));
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
                decoration: const InputDecoration(labelText: 'Nama Bisnis (Barbershop)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama bisnis wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _legalNameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Legal Perusahaan'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerNameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Pemilik'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama pemilik wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerEmailCtrl,
                decoration: const InputDecoration(labelText: 'Email Pemilik (Google account)'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerPhoneCtrl,
                decoration: const InputDecoration(labelText: 'Nomor Telepon Pemilik'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Alamat Lengkap'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _taxIdCtrl,
                decoration: const InputDecoration(labelText: 'NPWP / Tax ID (opsional)'),
              ),

              const SizedBox(height: 16),
              const Text('Pilih Paket', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'monthly',
                      groupValue: _plan,
                      title: const Text('Bulanan - Rp 300.000'),
                      onChanged: (v) => setState(() => _plan = v ?? 'monthly'),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'yearly',
                      groupValue: _plan,
                      title: const Text('Tahunan - Rp 3.000.000 (promo)'),
                      onChanged: (v) => setState(() => _plan = v ?? 'monthly'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Text('Setelah menekan Daftar, Anda akan diarahkan ke halaman lanjutan untuk mengunggah dokumen dan bukti pembayaran.', style: TextStyle(fontSize: 14)),
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

  const TenantContinueScreen({super.key, required this.tenantId, required this.amount});

  @override
  State<TenantContinueScreen> createState() => _TenantContinueScreenState();
}

class _TenantContinueScreenState extends State<TenantContinueScreen> {
  final TenantService _tenantService = TenantService();
  bool _isSubmitting = false;
  Future<void> _submitPaymentProof(File proofFile) async {
    setState(() => _isSubmitting = true);
    try {
      final proofUrl = await _tenantService.uploadTenantDocument(widget.tenantId, proofFile, filename: 'payment_proof_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      await _tenantService.submitRegistrationPayment(tenantId: widget.tenantId, proofUrl: proofUrl, userId: userId);

      // update invoice status
      await FirebaseFirestore.instance.collection('tenants').doc(widget.tenantId).set({
        'invoice': {
          'status': 'payment_submitted',
          'submitted_at': Timestamp.now(),
        }
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bukti pembayaran terkirim. Menunggu verifikasi admin.')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengirim bukti pembayaran: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
              onUploaded: (url) async {
                await _tenantService.updateTenantApplication(widget.tenantId, {'company_doc_url': url});
              },
            ),
            const SizedBox(height: 12),
            DocumentUploadWidget(
              tenantId: widget.tenantId,
              tenantService: _tenantService,
              label: 'NPWP / Dokumen Pajak',
              onUploaded: (url) async {
                await _tenantService.updateTenantApplication(widget.tenantId, {'tax_doc_url': url});
              },
            ),
            const SizedBox(height: 24),
            Text('Pembayaran pendaftaran: Rp ${widget.amount}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final res = await FilePicker.platform.pickFiles();
                      if (res == null || res.files.single.path == null) return;
                      final file = File(res.files.single.path!);
                      await _submitPaymentProof(file);
                    },
              icon: const Icon(Icons.upload_file),
              label: _isSubmitting ? const Text('Mengirim...') : const Text('Unggah Bukti Pembayaran'),
            ),
          ],
        ),
      ),
    );
  }
}
