import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';
import 'package:geges_smartbarber/screens/auth_gate.dart';
import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final l10n = AppLocalizations.of(context)!;
    // Tampilkan dialog konfirmasi dengan warning refund
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelRegistrationTitle),
        content: Text(l10n.cancelRegistrationWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.btnBack),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDanger),
            onPressed: () => Navigator.of(ctx).pop(true),
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
          reason: 'Dibatalkan oleh user (Request Refund)',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.msgCancelSent)),
        );
        Navigator.pop(context); // Kembali ke list
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

  void _contactSupport() async {
    final l10n = AppLocalizations.of(context)!;
    final Uri whatsappUrl = Uri.parse("https://wa.me/6281234567890"); // Ganti nomor support
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
    final tempPassword = widget.data['temp_password'] ?? l10n.contactAdmin;

    // Status Logic
    String statusText = l10n.statusAwaitingPayment;
    Color statusColor = kBrownAccent;
    
    if (status == 'active') {
      statusText = l10n.statusActiveCompleted;
      statusColor = Colors.green;
    } else if (status == 'rejected' || status == 'cancelled' || invStatus == 'cancelled_by_owner') {
      statusText = l10n.statusCancelledRejected;
      statusColor = kDanger;
    } else if (hasProof || verificationStatus == 'pending') {
      statusText = l10n.statusWaitingVerification;
      statusColor = Colors.blue;
    } else if (status == 'cancellation_requested') {
      statusText = l10n.statusRefundProcessing;
      statusColor = Colors.orange;
    }

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        title: Text(l10n.registrationDetail),
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
                  _buildSectionTitle(l10n.businessInfo),
                  _buildInfoTile(l10n.barbershopName, businessName),
                  _buildInfoTile(l10n.subscriptionPlan, plan.toString().toUpperCase()),
                  _buildInfoTile(l10n.registrationFee, _formatCurrency(fee)),
                  _buildInfoTile(l10n.address, widget.data['address'] ?? '-'),
                  const SizedBox(height: 24),

                  // 3. Credential (Jika Aktif)
                  if (status == 'active') ...[
                    _buildSectionTitle(l10n.adminAccountTitle),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kDarkGrey,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        children: [
                          Text(l10n.adminAccountDesc, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 12),
                          _buildCopyableRow(l10n.email, adminEmail),
                          const Divider(color: Colors.white24),
                          _buildCopyableRow(l10n.password, tempPassword),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kBrownAccent,
                                foregroundColor: Colors.black,
                              ),
                              icon: const Icon(Icons.login),
                              label: Text(l10n.btnLogoutLoginAdmin),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(l10n.loginAsAdminTitle),
                                    content: Text(l10n.loginAsAdminMsg),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: Text(l10n.cancel),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: Text(l10n.btnYesLogout),
                                      ),
                                    ],
                                  ),
                                );
                                
                                if (confirm == true) {
                                  await FirebaseAuth.instance.signOut();
                                  if (!mounted) return;
                                  // Navigate to AuthGate to restart the auth flow
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const AuthGate()),
                                    (route) => false,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 4. Info Refund/Batal (Jika Batal)
                  if (status == 'cancelled' || status == 'rejected') ...[
                    _buildSectionTitle(l10n.cancelDetail),
                    _buildInfoTile(l10n.reason, invoice?['cancel_reason'] ?? widget.data['rejection_reason'] ?? '-'),
                    if (widget.data['refund_proof_url'] != null)
                       Padding(
                         padding: const EdgeInsets.only(top: 8.0),
                         child: ElevatedButton.icon(
                           icon: const Icon(Icons.download),
                           label: Text(l10n.viewRefundProof),
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
                      child: Text(l10n.btnPayNow),
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
                        child: Text(l10n.btnCancelRegistration),
                      ),
                    ),

                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.support_agent, color: kTextGrey),
                    label: Text(l10n.contactSupport, style: const TextStyle(color: kTextGrey)),
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
    final l10n = AppLocalizations.of(context)!;
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
              SnackBar(content: Text(l10n.copiedToClipboard)),
            );
          },
        ),
      ],
    );
  }
}