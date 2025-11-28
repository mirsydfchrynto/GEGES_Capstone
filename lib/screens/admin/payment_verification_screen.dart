// lib/screens/admin/payment_verification_screen.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;

class PaymentVerificationScreen extends StatefulWidget {
  const PaymentVerificationScreen({super.key});

  @override
  State<PaymentVerificationScreen> createState() => _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState extends State<PaymentVerificationScreen> {
  final QueueService _queueService = QueueService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _nameCache = {};

  Future<String> _getCustomerName(String customerId) async {
    if (_nameCache.containsKey('c_$customerId')) {
      return _nameCache['c_$customerId']!;
    }
    try {
      final doc = await _firestore.collection('users').doc(customerId).get();
      final name = doc.data()?['name'] ?? 'Customer';
      _nameCache['c_$customerId'] = name;
      return name;
    } catch (_) {
      return 'Customer';
    }
  }

  Future<String> _getBarbershopName(String id) async {
    if (_nameCache.containsKey('bs_$id')) return _nameCache['bs_$id']!;
    try {
      final doc = await _firestore.collection('barbershops').doc(id).get();
      final name = doc.data()?['name'] ?? 'Barbershop';
      _nameCache['bs_$id'] = name;
      return name;
    } catch (_) {
      return 'Barbershop';
    }
  }

  Future<String> _getServiceNames(List<String>? serviceIds) async {
    if (serviceIds == null || serviceIds.isEmpty) return 'Layanan';
    try {
      final docs = await Future.wait(
        serviceIds.map((id) => _firestore.collection('services').doc(id).get()),
      );
      final names = docs.where((d) => d.exists).map((d) => d.data()?['name'] as String? ?? 'S').toList();
      if (names.isEmpty) return 'Layanan';
      return names.length == 1 ? names[0] : '${names[0]} +${names.length - 1}';
    } catch (_) {
      return 'Layanan';
    }
  }

  Future<Map<String, dynamic>> _fetchDetails(Queue q) async {
    final results = await Future.wait([
      _getCustomerName(q.customerId),
      _getBarbershopName(q.barbershopId),
      _getServiceNames(q.serviceIds),
    ]);
    return {
      'customer': results[0],
      'shop': results[1],
      'service': results[2],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Verifikasi Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: StreamBuilder<List<Queue>>(
        stream: _queueService.streamAllQueues(statusFilter: ['awaiting_payment']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kBrownAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.payment, color: kTextGrey, size: 60),
                SizedBox(height: 16),
                Text('Tidak ada pembayaran untuk diverifikasi', style: TextStyle(color: kTextGrey))
              ]),
            );
          }

          requests.sort((a, b) {
            if (a.paymentDeadline == null || b.paymentDeadline == null) return 0;
            return a.paymentDeadline!.compareTo(b.paymentDeadline!);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, i) => _buildCard(context, requests[i]),
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, Queue q) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchDetails(q),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 130,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: kDarkGrey, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: CircularProgressIndicator(color: kBrownAccent)),
          );
        }

        final d = snapshot.data!;
        final isExpired = q.paymentDeadline != null && DateTime.now().isAfter(q.paymentDeadline!.toDate());
        final hasProof = q.paymentProofBase64 != null && q.paymentProofBase64!.isNotEmpty;

        return GestureDetector(
          onTap: () => _showDetail(context, q, d),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: kDarkGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isExpired ? Colors.red : (hasProof ? Colors.green : Colors.orange), width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['shop'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(d['customer'], style: const TextStyle(color: kTextGrey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isExpired ? Colors.red : (hasProof ? Colors.green : Colors.orange),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isExpired ? 'EXPIRED' : (hasProof ? 'PROOF OK' : 'WAITING'),
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 11, color: kTextGrey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(DateFormat('EEE d MMM HH:mm').format(q.bookingTime.toDate()), style: const TextStyle(color: kTextGrey, fontSize: 10))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.hourglass_bottom, size: 11, color: kTextGrey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          q.paymentDeadline != null
                              ? DateFormat('d MMM HH:mm').format(q.paymentDeadline!.toDate())
                              : 'No deadline',
                          style: TextStyle(color: isExpired ? Colors.red : kTextGrey, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  if (q.totalPrice != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.money, size: 11, color: kBrownAccent),
                        const SizedBox(width: 4),
                        Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(q.totalPrice), style: const TextStyle(color: kBrownAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, Queue q, Map<String, dynamic> d) {
    final noteCtrl = TextEditingController();
    final hasProof = q.paymentProofBase64 != null && q.paymentProofBase64!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: kDarkGrey,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Container(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Verifikasi Pembayaran', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                GestureDetector(onTap: () => Navigator.pop(c), child: const Icon(Icons.close, color: Colors.white))
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Status', 'AWAITING PAYMENT', Colors.orange),
                    _row('Customer', d['customer']),
                    _row('Shop', d['shop']),
                    _row('Service', d['service']),
                    _row('Booking Time', DateFormat('EEE d MMM HH:mm').format(q.bookingTime.toDate())),
                    if (q.estimatedDuration != null) _row('Duration', '${q.estimatedDuration} min'),
                    if (q.totalPrice != null) _row('Price', NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(q.totalPrice), kBrownAccent),
                    if (q.paymentDeadline != null) _row('Deadline', DateFormat('EEE d MMM HH:mm').format(q.paymentDeadline!.toDate())),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (hasProof) ...[
                const Text('Bukti Pembayaran', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: Image.memory(base64Decode(q.paymentProofBase64!), fit: BoxFit.contain),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: c,
                      builder: (dc) => AlertDialog(
                        backgroundColor: kDarkGrey,
                        content: SingleChildScrollView(child: Image.memory(base64Decode(q.paymentProofBase64!))),
                        actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Tutup'))],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], minimumSize: const Size(double.infinity, 40)),
                  child: const Text('Lihat Full Size'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Belum ada bukti pembayaran', style: TextStyle(color: Colors.red, fontSize: 12)))
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text('Catatan (opsional)', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 6),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'E.g. Nomor rekening tidak cocok, jumlah kurang',
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !hasProof
                          ? null
                          : () async {
                              try {
                                await _queueService.adminConfirmPayment(q.id, adminNotes: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
                                if (c.mounted) {
                                  Navigator.pop(c);
                                  if (c.mounted) {
                                    ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Pembayaran dikonfirmasi'), backgroundColor: Colors.green));
                                  }
                                }
                              } catch (e) {
                                if (c.mounted) {
                                  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrownAccent,
                        minimumSize: const Size.fromHeight(44),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: const Text('Konfirmasi'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _queueService.adminRejectPayment(q.id, reason: noteCtrl.text.trim().isEmpty ? 'Bukti tidak valid' : noteCtrl.text.trim());
                          if (c.mounted) {
                            Navigator.pop(c);
                            if (c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Pembayaran ditolak'), backgroundColor: Colors.red));
                            }
                          }
                        } catch (e) {
                          if (c.mounted) {
                            ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size.fromHeight(44)),
                      child: const Text('Tolak'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String val, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: kTextGrey, fontSize: 12)),
          Text(val, style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w600))
        ],
      ),
    );
  }
}
