// lib/screens/tenant_registration_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/models/tenant.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';

/// A compact, testable tenant registration + payment flow.
/// - Single-file (≤300 lines)
/// - Uses DI-friendly services for persistence, payment, and notifications

class TenantRegistrationScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final TenantServiceContract? tenantService;
  final PaymentService? paymentService;
  final NotificationService? notificationService;
  final bool disableCountdown; // useful for tests to avoid periodic timers

  const TenantRegistrationScreen({super.key, this.firestore, this.tenantService, this.paymentService, this.notificationService, this.disableCountdown = false});

  @override
  State<TenantRegistrationScreen> createState() => _TenantRegistrationScreenState();
}

class _TenantRegistrationScreenState extends State<TenantRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  String? _base64Doc;
  String _package = 'basic';
  bool _submitting = false;
  Invoice? _activeInvoice;
  Timer? _tick;

  TenantServiceContract get _tenantService => widget.tenantService ?? TenantService(firestore: widget.firestore ?? FirebaseFirestore.instance);
  PaymentService get _paymentService => widget.paymentService ?? DummyPaymentService();
  NotificationService get _notificationService => widget.notificationService ?? DummyNotificationService();

  Tenant? _activeTenant;
  bool _hasActiveRegistration = false;

  @override
  void initState() {
    super.initState();
    _checkActiveRegistration();
  }

  @override
  void dispose() {
    _formKey.currentState?.dispose();
    _businessName.dispose();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _checkActiveRegistration() async {
    try {
      // best-effort: check for an existing in-progress registration for current user
      final currentUserId = (() {
        try {
          // Prefer FirebaseAuth uid when available
          // ignore: avoid_top_level_imports
          return FirebaseAuth.instance.currentUser?.uid ?? FirebaseFirestore.instance.app.options.projectId;
        } catch (_) {
          return 'test-owner'; // test fallback
        }
      })();

      final existing = await _tenantService.getActiveRegistrationForOwner(currentUserId);
      if (existing != null) {
        setState(() {
          _activeTenant = existing;
          _hasActiveRegistration = true;
          // If draft, prefill business name and package for convenience
          if (_activeTenant!.businessName.isNotEmpty) _businessName.text = _activeTenant!.businessName;
          if (_activeTenant!.packageId.isNotEmpty) _package = _activeTenant!.packageId;
        });
      }
    } catch (_) {
      // ignore errors — non-critical
    }
  }

  Future<void> _pickDocument(String content) async {
    // For simplicity, accept a base64 input (in real app pick file and convert to base64)
    setState(() => _base64Doc = base64Encode(utf8.encode(content)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_base64Doc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dokumen diperlukan')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final tenant = await _tenantService.createTenant(
        businessName: _businessName.text.trim(),
        documentBase64: _base64Doc!,
        packageId: _package,
      );

      final invoice = await _paymentService.createInvoice(tenantId: tenant.id, amount: _package == 'pro' ? 200000 : 50000);
      if (!mounted) return;
      setState(() => _activeInvoice = invoice);

      // attach invoice to tenant and start countdown
      await _tenantService.attachInvoice(tenant.id, invoiceId: invoice.id, deadline: invoice.deadline);

      // show payment screen modal (simplified): user can "pay now" or leave. paymentService simulates status.
      if (!widget.disableCountdown) _startCountdown();

      // capture messenger before awaiting to avoid using BuildContext across async gap
      // ignore: use_build_context_synchronously
      final messenger = ScaffoldMessenger.of(context);
      // show payment dialog (awaits) — messenger was captured above
      // ignore: use_build_context_synchronously
      final paid = await showDialog<bool>(context: context, builder: (_) => PaymentDialog(invoice: invoice, paymentService: _paymentService));

      if (!mounted) return;
      if (paid == true) {
        await _tenantService.markPaid(tenant.id, invoice.id);
        _notificationService.notify('Pendaftaran berhasil', 'Tunggu konfirmasi maksimal 1 minggu');
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Pembayaran berhasil — tunggu konfirmasi (maks 1 minggu)')));
      } else {
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Pembayaran belum dilakukan — order akan otomatis dibatalkan jika melewati deadline')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  void _startCountdown() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_activeInvoice == null) return;
      final now = DateTime.now();
      if (_activeInvoice!.deadline.isBefore(now)) {
        _tick?.cancel();
        await _paymentService.autoCancel(_activeInvoice!.id);
        if (!mounted) return;
        setState(() => _activeInvoice = null);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order dibatalkan karena waktu pembayaran habis')));
      } else {
        if (!mounted) return;
        setState(() {}); // refresh to show remaining
      }
    });
  }

  String _formatRemaining() {
if (_activeInvoice == null) return '';
    final rem = _activeInvoice!.deadline.difference(DateTime.now());
    if (rem.isNegative) return '00:00:00';
    final h = rem.inHours.toString().padLeft(2, '0');
    final m = (rem.inMinutes.remainder(60)).toString().padLeft(2, '0');
    final s = (rem.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Tenant')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _businessName, decoration: const InputDecoration(labelText: 'Nama Bisnis'), validator: (v) => v == null || v.trim().isEmpty ? 'Harus diisi' : null),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(initialValue: _package, items: const [DropdownMenuItem(value: 'basic', child: Text('Basic — Rp50.000')), DropdownMenuItem(value: 'pro', child: Text('Pro — Rp200.000'))], onChanged: (v) => setState(() => _package = v!)),
              const SizedBox(height: 12),
              ElevatedButton.icon(onPressed: () => _pickDocument('contoh dokumen'), icon: const Icon(Icons.upload_file), label: const Text('Unggah Dokumen (conto)')),
              if (_base64Doc != null) ...[
                const SizedBox(height: 8),
                const Text('Dokumen terlampir', style: TextStyle(color: Colors.green)),
              ],
              const SizedBox(height: 20),
              if (_activeInvoice != null) ...[
                Text('Pembayaran tertunda — sisa waktu: ${_formatRemaining()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
              ],
              if (_hasActiveRegistration) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(((_activeTenant?.status ?? '') == 'draft') ? 'Anda memiliki pendaftaran yang belum selesai' : 'Anda memiliki pendaftaran dalam proses', style: const TextStyle(color: Colors.amber)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // Resume: if draft -> prefilled form, if awaiting_payment -> open payment
                                if (_activeTenant == null) return;
                                if (_activeTenant!.status == 'draft') {
                                  // keep form prefilled; scroll to top so user can edit
                                  // no-op here — form already prefilled
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lanjutkan mengisi formulir pendaftaran')));
                                } else {
                                  // open payment screen for tenant
                                  if (!mounted) return;
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(orderId: _activeTenant!.id, totalPrice: 0, tenantId: _activeTenant!.id)));
                                }
                              },
                              child: Text(((_activeTenant?.status ?? '') == 'draft') ? 'Lanjutkan Pendaftaran' : 'Lanjutkan Pembayaran'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () async {
                              if (_activeTenant == null) return;
                              // Resolve a user id for cancel operation without relying on Firebase being initialized in tests
                              String userId = 'unknown';
                              try {
                                userId = FirebaseAuth.instance.currentUser?.uid ?? FirebaseFirestore.instance.app.options.projectId;
                              } catch (_) {
                                userId = 'test-owner';
                              }

                              // Capture messenger before awaiting to avoid using BuildContext across async gaps
                              final messenger = ScaffoldMessenger.of(context);

                              await _tenantService.cancelRegistrationByOwner(tenantId: _activeTenant!.id, userId: userId);
                              if (!mounted) return;
                              setState(() { _hasActiveRegistration = false; _activeTenant = null; });
                              messenger.showSnackBar(const SnackBar(content: Text('Pendaftaran dibatalkan')));
                            },
                            child: const Text('Batalkan'),
                          ),
                        ],
                      )
                    ],
                  ),
                )
              ] else ...[
                ElevatedButton(onPressed: _submitting ? null : _submit, child: _submitting ? const CircularProgressIndicator() : const Text('Daftar & Bayar')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Minimal models and services

abstract class PaymentService {
  Future<Invoice> createInvoice({required String tenantId, required int amount});
  Future<void> autoCancel(String invoiceId);
  Future<bool> pay(String invoiceId);
}

abstract class NotificationService { void notify(String title, String body); }

// Lightweight fake implementations for testability
 

class DummyPaymentService implements PaymentService {
  final Map<String, Invoice> _invoices = {};
  @override
  Future<Invoice> createInvoice({required String tenantId, required int amount}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final invoice = Invoice(id: id, tenantId: tenantId, deadline: DateTime.now().add(const Duration(hours: 1)));
    _invoices[id] = invoice;
    return invoice;
  }

  // helper for tests to seed an invoice id
  void seedInvoice(Invoice invoice) {
    _invoices[invoice.id] = invoice;
  }

  @override
  Future<void> autoCancel(String invoiceId) async {
    _invoices.remove(invoiceId);
  }

  @override
  Future<bool> pay(String invoiceId) async {
    final inv = _invoices[invoiceId];
    if (inv == null) return false;
    inv.paid = true;
    return true;
  }
} 

class DummyNotificationService implements NotificationService { @override void notify(String t, String b) { /* no-op for tests */ } }

// Simple payment dialog for user to "pay" or cancel
class PaymentDialog extends StatelessWidget {
  final Invoice invoice;
  final PaymentService paymentService;
  const PaymentDialog({super.key, required this.invoice, required this.paymentService});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pembayaran'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Invoice ID: ${invoice.id}'), Text('Deadline: ${invoice.deadline}')]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(onPressed: () async { final ok = await paymentService.pay(invoice.id); // ignore: use_build_context_synchronously
          // ignore: use_build_context_synchronously
          Navigator.pop(context, ok); }, child: const Text('Bayar Sekarang')),
      ],
    );
  }
}
