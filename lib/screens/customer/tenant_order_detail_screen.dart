import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';
import 'package:geges_smartbarber/screens/auth/auth_gate.dart';
import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;
const Color kDanger = Color(0xFFD32F2F);
const Color kSuccess = Color(0xFF4CAF50);
const Color kInfo = Color(0xFF2196F3);
const Color kWarning = Color(0xFFFF9800);

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

  String _formatCurrency(int amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  Future<void> _handleRequestRefund() async {
    final l10n = AppLocalizations.of(context)!;
    String? reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String input = '';
        return AlertDialog(
          backgroundColor: kDarkGrey,
          title: Text(l10n.cancelRegistrationTitle, style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Updated warning text
              const Text(
                'Peringatan: Dana refund akan dikembalikan dengan potongan biaya admin 10% sesuai ketentuan.',
                style: TextStyle(color: kWarning, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(l10n.cancelRegistrationWarning, style: const TextStyle(color: kTextGrey)),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => input = v,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: l10n.reason,
                  hintStyle: const TextStyle(color: Colors.white38),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kBrownAccent)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.btnBack, style: const TextStyle(color: kTextGrey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kDanger),
              onPressed: () {
                 if (input.trim().isEmpty) return;
                 Navigator.pop(ctx, input);
              },
              child: Text(l10n.btnYesCancel),
            ),
          ],
        );
      },
    );

    if (reason != null) {
      setState(() => _isLoading = true);
      try {
        if (widget.tenantService is TenantService) {
           await (widget.tenantService as TenantService).requestCancellation(
            tenantId: widget.tenantId,
            userId: widget.currentUserId,
            reason: reason,
          );
        } else {
           // Fallback for contract (mostly tests)
           await widget.tenantService.cancelRegistrationByOwner(
            tenantId: widget.tenantId,
            userId: widget.currentUserId,
            reason: reason,
          );
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.msgCancelSent)),
        );
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errCancelFailed(e.toString()))),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleCancellation() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDarkGrey,
        title: Text(l10n.cancelRegistrationTitle, style: const TextStyle(color: Colors.white)),
        content: Text(l10n.cancelRegistrationWarning, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.btnBack, style: const TextStyle(color: kTextGrey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.btnYesCancel),
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
          reason: 'User cancelled before payment',
        );
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membatalkan: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _contactSupport() async {
    final l10n = AppLocalizations.of(context)!;
    final Uri whatsappUrl = Uri.parse("https://wa.me/6281234567890"); 
    if (!await launchUrl(whatsappUrl)) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errOpenWhatsApp)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = widget.data['status'] as String? ?? 'draft';
    final businessName = widget.data['business_name'] ?? '-';
    final plan = widget.data['plan'] ?? '-';
    final fee = widget.data['registration_fee'] as int? ?? 0;
    
    final invoice = widget.data['invoice'] as Map<String, dynamic>?;
    final invStatus = invoice?['status'] as String?;
    final payment = widget.data['payment'] as Map<String, dynamic>?;
    final hasProof = (payment?['payment_proof_base64'] != null) || (payment?['proofUrl'] != null);
    final verificationStatus = payment?['verificationStatus'];
    
    // New fields for refund
    final refundStatus = widget.data['refund_status'] as String?;
    final refundProofUrl = widget.data['refund_proof_url'] as String?;
    final cancelReason = invoice?['cancel_reason'] as String?;

    final adminEmail = widget.data['admin_email'] ?? widget.data['owner_email'];
    final tempPassword = widget.data['temp_password'] ?? l10n.contactAdmin;

    String statusText = l10n.statusAwaitingPayment;
    Color statusColor = kBrownAccent;
    IconData statusIcon = Icons.hourglass_empty;
    String? statusDesc;
    
    if (status == 'active') {
      statusText = l10n.statusActiveCompleted;
      statusColor = kSuccess;
      statusIcon = Icons.check_circle_outline;
    } else if (status == 'cancellation_requested') {
      statusText = l10n.statusRefundWaiting;
      statusColor = kWarning;
      statusIcon = Icons.access_time_filled;
      statusDesc = l10n.descRefundWaiting;
    } else if (status == 'cancelled' && refundStatus == 'completed') {
      statusText = l10n.statusRefundCompleted;
      statusColor = Colors.teal;
      statusIcon = Icons.assignment_return;
    } else if (status == 'rejected' || status == 'cancelled' || invStatus == 'cancelled_by_owner') {
      statusText = l10n.statusCancelledRejected;
      statusColor = kDanger;
      statusIcon = Icons.cancel_outlined;
    } else if (hasProof || verificationStatus == 'pending') {
      statusText = l10n.statusWaitingVerification;
      statusColor = kInfo;
      statusIcon = Icons.verified_user_outlined;
    } 

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.registrationDetail,
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: kBrownAccent))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status Badge Card
                    _buildStatusCard(statusText, statusColor, statusIcon),
                    if (statusDesc != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          statusDesc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Main Info Card
                    _buildMainCard(l10n, businessName, plan, fee),
                    const SizedBox(height: 24),

                    // Account Credentials (if active)
                    if (status == 'active') ...[
                      _buildAdminAccountCard(l10n, adminEmail, tempPassword),
                      const SizedBox(height: 24),
                    ],

                    // Refund Completed Info
                    if (status == 'cancelled' && refundStatus == 'completed') ...[
                      _buildRefundCompletedCard(l10n, cancelReason, refundProofUrl),
                      const SizedBox(height: 24),
                    ],

                    // Cancellation Info (Standard)
                    if ((status == 'cancelled' || status == 'rejected') && refundStatus != 'completed') ...[
                      _buildCancellationCard(l10n, invoice, widget.data),
                      const SizedBox(height: 24),
                    ],

                    // Footer Actions
                    _buildActionButtons(l10n, status, hasProof, fee, invoice),
                    
                    const SizedBox(height: 32),
                    _buildContactSupport(l10n),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard(String text, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 12),
          Text(
            text.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(AppLocalizations l10n, String name, String plan, int fee) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kDarkGrey,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(Icons.store, l10n.barbershopName, name),
          const Divider(color: Colors.white10, height: 32),
          _buildDetailRow(Icons.layers, l10n.subscriptionPlan, plan.toString().toUpperCase()),
          const Divider(color: Colors.white10, height: 32),
          _buildDetailRow(Icons.payments, l10n.registrationFee, _formatCurrency(fee), valueColor: kBrownAccent),
          const Divider(color: Colors.white10, height: 32),
          _buildDetailRow(Icons.location_on, l10n.address, widget.data['address'] ?? '-', isLong: true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor, bool isLong = false}) {
    return Row(
      crossAxisAlignment: isLong ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kBrownAccent, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: isLong ? 3 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdminAccountCard(AppLocalizations l10n, String email, String pass) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kSuccess.withValues(alpha: 0.1), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kSuccess.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key, color: kSuccess, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.adminAccountTitle.toUpperCase(),
                style: const TextStyle(color: kSuccess, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.adminAccountDesc, style: const TextStyle(color: kTextGrey, fontSize: 13)),
          const SizedBox(height: 20),
          _buildCredentialBox(l10n.email, email),
          const SizedBox(height: 12),
          _buildCredentialBox(l10n.password, pass),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrownAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: const Icon(Icons.logout_rounded),
              label: Text(l10n.btnLogoutLoginAdmin, style: const TextStyle(fontWeight: FontWeight.w800)),
              onPressed: _showLogoutConfirm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: kBrownAccent, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.copiedToClipboard)));
            },
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDarkGrey,
        title: Text(l10n.loginAsAdminTitle, style: const TextStyle(color: Colors.white)),
        content: Text(l10n.loginAsAdminMsg, style: const TextStyle(color: kTextGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel, style: const TextStyle(color: kTextGrey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.btnYesLogout),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  Widget _buildCancellationCard(AppLocalizations l10n, Map<String, dynamic>? invoice, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kDanger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kDanger.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.cancelDetail.toUpperCase(), style: const TextStyle(color: kDanger, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 16),
          Text(invoice?['cancel_reason'] ?? data['rejection_reason'] ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          if (data['refund_proof_url'] != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
                icon: const Icon(Icons.receipt_long_rounded),
                label: Text(l10n.viewRefundProof),
                onPressed: () => launchUrl(Uri.parse(data['refund_proof_url'])),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildRefundCompletedCard(AppLocalizations l10n, String? adminNote, String? proofUrl) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.teal),
              const SizedBox(width: 8),
              Text('REFUND SELESAI', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
          if (adminNote != null && adminNote.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('${l10n.adminNote}:', style: const TextStyle(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(adminNote, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
          if (proofUrl != null) ...[
            const SizedBox(height: 24),
            Text(l10n.viewRefundProof, style: const TextStyle(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(proofUrl)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: proofUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (c, u) => Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (c, u, e) => Container(color: Colors.black26, child: const Icon(Icons.broken_image, color: Colors.white24)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n, String status, bool hasProof, int fee, Map<String, dynamic>? invoice) {
    if (status == 'active' || status == 'cancelled' || status == 'rejected' || status == 'cancellation_requested') {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (status == 'awaiting_payment' && !hasProof)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrownAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final deadlineTs = invoice?['payment_deadline'] as Timestamp?;
                Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(
                  orderId: widget.tenantId,
                  totalPrice: fee,
                  tenantId: widget.tenantId,
                  tenantPaymentHandler: ({required String tenantId, required String base64, required String userId}) async {
                    await widget.tenantService.submitRegistrationPayment(tenantId: tenantId, proofBase64: base64, userId: userId);
                  },
                  cancelTenantHandler: ({required String tenantId, required String userId, String? reason}) async {
                    await widget.tenantService.cancelRegistrationByOwner(tenantId: tenantId, userId: userId, reason: reason);
                  },
                  disableTimer: false,
                  paymentDeadline: deadlineTs?.toDate(),
                  testUserId: widget.currentUserId,
                )));
              },
              child: Text(l10n.btnPayNow, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        
        // Show "Batalkan & Minta Refund" if paid/waiting verification
        // Show "Batalkan Pendaftaran" if unpaid
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: kDanger,
              side: const BorderSide(color: kDanger),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: (hasProof) ? _handleRequestRefund : _handleCancellation,
            child: Text(
              hasProof ? l10n.btnRequestRefund : l10n.btnCancelRegistration, 
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSupport(AppLocalizations l10n) {
    return Center(
      child: GestureDetector(
        onTap: _contactSupport,
        child: Column(
          children: [
            const Icon(Icons.headset_mic_rounded, color: kTextGrey, size: 28),
            const SizedBox(height: 8),
            Text(
              l10n.contactSupport,
              style: const TextStyle(color: kTextGrey, decoration: TextDecoration.underline, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
