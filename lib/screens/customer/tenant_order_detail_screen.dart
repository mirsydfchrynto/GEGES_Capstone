import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';
import 'package:url_launcher/url_launcher.dart'; // Pastikan package ini ada, jika tidak saya pakai print dulu

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;
const Color kDanger = Color(0xFFD32F2F);

class TenantOrderDetailScreen extends StatefulWidget {
  final String tenantId;
  final Map<String, dynamic> data;
  final TenantServiceContract tenantService;
  final String currentUserId;

  const TenantOrderDetailScreen({
    super.key,
    required this.tenantId,
    required this.data,
    required this.tenantService,
    required this.currentUserId,
  });

  @override
  State<TenantOrderDetailScreen> createState() => _TenantOrderDetailScreenState();
}

class _TenantOrderDetailScreenState extends State<TenantOrderDetailScreen> {
  bool _isLoading = false;

  // Helper untuk format currency
  String _formatCurrency(int amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  Future<void> _handleCancellation() async {
    // Tampilkan dialog konfirmasi dengan warning refund
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pendaftaran?'),
        content: const Text(
          'Jika Anda membatalkan pendaftaran yang SUDAH DIBAYAR, dana akan dikembalikan dengan POTONGAN 10% (biaya admin).\n\nApakah Anda yakin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDanger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await widget.tenantService.cancelRegistrationByOwner(
          tenantId: widget.tenantId,
          userId: widget.currentUserId,
          reason: 'Dibatalkan oleh user (Request Refund)',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permintaan pembatalan dikirim.')),
        );
        Navigator.pop(context); // Kembali ke list
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membatalkan: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _contactSupport() async {
    final Uri whatsappUrl = Uri.parse("https://wa.me/6281234567890"); // Ganti nomor support
    if (!await launchUrl(whatsappUrl)) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka WhatsApp support')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Parsing Data
    final status = widget.data['status'] as String? ?? 'draft';
    final businessName = widget.data['business_name'] ?? '-';
    final plan = widget.data['plan'] ?? '-';
    final fee = widget.data['registration_fee'] as int? ?? 0;
    
    // Payment info
    final invoice = widget.data['invoice'] as Map<String, dynamic>?;
    final invStatus = invoice?['status'] as String?;
    final payment = widget.data['payment'] as Map<String, dynamic>?;
    final hasProof = (payment?['payment_proof_base64'] != null) || (payment?['proofUrl'] != null);
    final verificationStatus = payment?['verificationStatus'];

    // Credential Info (Only if active)
    final adminEmail = widget.data['admin_email'] ?? widget.data['owner_email'];
    final tempPassword = widget.data['temp_password'] ?? 'Hubungi Admin';

    // Status Logic
    String statusText = 'MENUNGGU PEMBAYARAN';
    Color statusColor = kBrownAccent;
    
    if (status == 'active') {
      statusText = 'AKTIF / SELESAI';
      statusColor = Colors.green;
    } else if (status == 'rejected' || status == 'cancelled' || invStatus == 'cancelled_by_owner') {
      statusText = 'DIBATALKAN';
      statusColor = kDanger;
    } else if (hasProof || verificationStatus == 'pending') {
      statusText = 'MENUNGGU VERIFIKASI';
      statusColor = Colors.blue;
    } else if (status == 'cancellation_requested') {
      statusText = 'REFUND DIPROSES';
      statusColor = Colors.orange;
    }

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        title: const Text('Detail Pendaftaran'),
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: kBrownAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: statusColor),
                        const SizedBox(width: 12),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 16
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Info Bisnis
                  _buildSectionTitle('Informasi Bisnis'),
                  _buildInfoTile('Nama Barbershop', businessName),
                  _buildInfoTile('Paket Langganan', plan.toString().toUpperCase()),
                  _buildInfoTile('Biaya Pendaftaran', _formatCurrency(fee)),
                  _buildInfoTile('Alamat', widget.data['address'] ?? '-'),
                  const SizedBox(height: 24),

                  // 3. Credential (Jika Aktif)
                  if (status == 'active') ...[
                    _buildSectionTitle('Akun Admin Barbershop'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kDarkGrey,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        children: [
                          const Text('Gunakan akun ini untuk login ke Aplikasi Admin:', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 12),
                          _buildCopyableRow('Email', adminEmail),
                          const Divider(color: Colors.white24),
                          _buildCopyableRow('Password', tempPassword),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 4. Info Refund/Batal (Jika Batal)
                  if (status == 'cancelled' || status == 'rejected') ...[
                    _buildSectionTitle('Detail Pembatalan'),
                    _buildInfoTile('Alasan', invoice?['cancel_reason'] ?? widget.data['rejection_reason'] ?? '-'),
                    if (widget.data['refund_proof_url'] != null)
                       Padding(
                         padding: const EdgeInsets.only(top: 8.0),
                         child: ElevatedButton.icon(
                           icon: const Icon(Icons.download),
                           label: const Text('Lihat Bukti Refund'),
                           onPressed: () {
                             // Implementasi view image/url
                             launchUrl(Uri.parse(widget.data['refund_proof_url']));
                           },
                         ),
                       ),
                    const SizedBox(height: 24),
                  ],

                  // 5. Action Buttons
                  if (status == 'awaiting_payment' && !hasProof)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrownAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                         final deadlineTs = invoice?['payment_deadline'] as Timestamp?;
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (_) => PaymentScreen(
                               orderId: widget.tenantId,
                               totalPrice: fee,
                               tenantId: widget.tenantId,
                               tenantPaymentHandler: ({required String tenantId, required String base64, required String userId}) async {
                                 await widget.tenantService.submitRegistrationPayment(
                                   tenantId: tenantId,
                                   proofBase64: base64,
                                   userId: userId,
                                 );
                               },
                               cancelTenantHandler: ({required String tenantId, required String userId, String? reason}) async {
                                 await widget.tenantService.cancelRegistrationByOwner(tenantId: tenantId, userId: userId, reason: reason);
                               },
                               disableTimer: false,
                               paymentDeadline: deadlineTs?.toDate(),
                               testUserId: widget.currentUserId,
                             ),
                           ),
                         );
                      },
                      child: const Text('BAYAR SEKARANG'),
                    ),

                  if (status != 'active' && status != 'cancelled' && status != 'rejected' && status != 'cancellation_requested')
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kDanger,
                          side: const BorderSide(color: kDanger),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _handleCancellation,
                        child: const Text('BATALKAN PENDAFTARAN'),
                      ),
                    ),

                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.support_agent, color: kTextGrey),
                    label: const Text('Hubungi Bantuan / Komplain', style: TextStyle(color: kTextGrey)),
                    onPressed: _contactSupport,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: kTextGrey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCopyableRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.copy, color: kBrownAccent),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Disalin ke clipboard')),
            );
          },
        ),
      ],
    );
  }
}
