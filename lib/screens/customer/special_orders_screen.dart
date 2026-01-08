import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';
import 'package:geges_smartbarber/screens/customer/tenant_order_detail_screen.dart';
import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;

class SpecialOrdersScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final String? currentUserId;

  const SpecialOrdersScreen({
    super.key,
    this.firestore,
    this.currentUserId,
  });

  @override
  State<SpecialOrdersScreen> createState() => _SpecialOrdersScreenState();
}

class _SpecialOrdersScreenState extends State<SpecialOrdersScreen> {
  FirebaseFirestore get _firestore =>
      widget.firestore ?? FirebaseFirestore.instance;
  String? get _customerId =>
      widget.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
  TenantServiceContract get _tenantService =>
      TenantService(firestore: _firestore);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_customerId == null) {
      return Scaffold(
        backgroundColor: kSurface,
        appBar: AppBar(
          backgroundColor: kSurface,
          elevation: 0,
          title: Text(l10n.specialOrders, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Text(l10n.pleaseLoginFirst, style: const TextStyle(color: kTextGrey)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        centerTitle: true,
        title: Text(l10n.specialOrders, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('tenants')
            .where('owner_uid', isEqualTo: _customerId!)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kBrownAccent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      l10n.errLoadingOrders(snapshot.error.toString()),
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: kDarkGrey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      size: 64,
                      color: kTextGrey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.noSpecialOrders,
                    style: const TextStyle(color: kTextGrey, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) => _buildOrderCard(docs[index]),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(QueryDocumentSnapshot doc) {
    final l10n = AppLocalizations.of(context)!;
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'draft';
    final businessName = data['business_name'] ?? 'Partnership Registration';
    final created = (data['created_at'] as Timestamp?)?.toDate();

    final payment = data['payment'] as Map<String, dynamic>?;
    final verificationStatus = payment?['verificationStatus'];
    final hasProof = (payment?['payment_proof_base64'] != null) ||
        (payment?['proofUrl'] != null);

    String statusLabel = l10n.statusAwaitingPayment;
    Color statusColor = kBrownAccent;
    String description = l10n.descAwaitingPayment;
    bool showPayButton = false;

    if (status == 'active') {
      statusLabel = l10n.statusActivePartnership;
      statusColor = Colors.green;
      description = l10n.descActivePartnership;
    } else if (status == 'rejected' || status == 'cancelled') {
      statusLabel = l10n.statusCancelledRejected;
      statusColor = Colors.red;
      description = l10n.descCancelledRejected;
    } else if (status == 'cancellation_requested') {
      statusLabel = l10n.statusRefundProcessing;
      statusColor = Colors.orange;
      description = 'Permintaan refund sedang ditinjau Admin.';
    } else if (hasProof || verificationStatus == 'pending') {
      statusLabel = l10n.statusWaitingVerification;
      statusColor = Colors.blue;
      description = l10n.descWaitingVerification;
    } else {
      statusLabel = l10n.statusAwaitingPayment;
      statusColor = kBrownAccent;
      showPayButton = true;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: kDarkGrey,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TenantOrderDetailScreen(
                    tenantId: doc.id,
                    data: data,
                    tenantService: _tenantService,
                    currentUserId: _customerId!,
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Indicator Strip
                Container(
                  height: 4,
                  width: double.infinity,
                  color: statusColor,
                ),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.stars_rounded, size: 18, color: statusColor),
                              const SizedBox(width: 8),
                              Text(
                                'PARTNERSHIP',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          if (created != null)
                            Text(
                              DateFormat('dd MMM yyyy').format(created),
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        businessName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              statusLabel.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        description,
                        style: const TextStyle(
                          color: kTextGrey,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      
                      if (showPayButton && data['invoice_id'] != null) ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBrownAccent,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              final invoice = data['invoice'] as Map<String, dynamic>?;
                              final amount = (invoice != null && invoice['amount'] != null)
                                  ? (invoice['amount'] as int)
                                  : (data['registration_fee'] as int?) ?? 0;
                              final deadlineTs = invoice?['payment_deadline'] as Timestamp?;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentScreen(
                                    orderId: doc.id,
                                    totalPrice: amount,
                                    tenantId: doc.id,
                                    tenantPaymentHandler: ({required String tenantId, required String base64, required String userId}) async {
                                      await _tenantService.submitRegistrationPayment(
                                        tenantId: tenantId,
                                        proofBase64: base64,
                                        userId: userId,
                                      );
                                    },
                                    cancelTenantHandler: ({required String tenantId, required String userId, String? reason}) async {
                                      await _tenantService.cancelRegistrationByOwner(
                                        tenantId: tenantId,
                                        userId: userId,
                                        reason: reason,
                                      );
                                    },
                                    disableTimer: false,
                                    paymentDeadline: deadlineTs?.toDate(),
                                    testUserId: _customerId,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              l10n.btnResumePayment,
                              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}