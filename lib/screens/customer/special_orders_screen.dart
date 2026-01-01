import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';
import 'package:geges_smartbarber/screens/customer/tenant_order_detail_screen.dart'; // Import Detail Screen

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
    if (_customerId == null) {
      return Scaffold(
        backgroundColor: kSurface,
        appBar: AppBar(
          backgroundColor: kSurface,
          title: const Text('Special Orders'),
        ),
        body: const Center(
          child: Text('Please login first', style: TextStyle(color: kTextGrey)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        title: const Text('Special Orders'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(color: Colors.white10, height: 1),
        ),
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
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading orders: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.folder_open_outlined,
                    size: 64,
                    color: kTextGrey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Belum ada Special Order',
                    style: TextStyle(color: kTextGrey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) => _buildOrderCard(docs[index]),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'draft';
    final businessName = data['business_name'] ?? 'Partnership Registration';
    final created = (data['created_at'] as Timestamp?)?.toDate();

    // Payment Logic
    final payment = data['payment'] as Map<String, dynamic>?;
    final verificationStatus = payment?['verificationStatus'];
    final hasProof = (payment?['payment_proof_base64'] != null) ||
        (payment?['proofUrl'] != null);

    // Determine UI State
    String statusLabel = 'Menunggu Pembayaran';
    Color statusColor = Colors.orange;
    String description = 'Selesaikan pembayaran untuk memproses pendaftaran.';
    bool showPayButton = false;

    if (status == 'active') {
      statusLabel = 'SUKSES / AKTIF';
      statusColor = Colors.green;
      description = 'Selamat! Partnership Anda telah aktif.';
    } else if (status == 'rejected' || status == 'cancelled') {
      statusLabel = 'DIBATALKAN / DITOLAK';
      statusColor = Colors.red;
      description = 'Permintaan ini tidak dapat diproses.';
    } else if (hasProof || verificationStatus == 'pending') {
      statusLabel = 'MENUNGGU VERIFIKASI';
      statusColor = Colors.blue;
      description = 'Bukti diterima. Admin sedang memverifikasi data Anda.';
    } else {
      // Default: Awaiting Payment
      statusLabel = 'MENUNGGU PEMBAYARAN';
      statusColor = kBrownAccent;
      showPayButton = true;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kDarkGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: InkWell(
        onTap: () {
          // Navigasi ke Detail Screen
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
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star_border, size: 16, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        'PARTNERSHIP',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  if (created != null)
                    Text(
                      DateFormat('dd MMM yyyy').format(created),
                      style: const TextStyle(color: kTextGrey, fontSize: 12),
                    ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    businessName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (showPayButton && data['invoice_id'] != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrownAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          final invoice =
                              data['invoice'] as Map<String, dynamic>?;
                          final amount =
                              (invoice != null && invoice['amount'] != null)
                                  ? (invoice['amount'] as int)
                                  : (data['registration_fee'] as int?) ?? 0;
                          final deadlineTs =
                              invoice?['payment_deadline'] as Timestamp?;

                          Navigator.push(
                            context,
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
                                          await _tenantService
                                              .submitRegistrationPayment(
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
                                          await _tenantService
                                              .cancelRegistrationByOwner(
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
                        child: const Text('LANJUTKAN PEMBAYARAN'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}