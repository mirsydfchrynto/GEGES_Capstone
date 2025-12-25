// My Bookings (riwayat pelanggan) — status tabs focused on payment-first flow
// Tab queries:
// 1. Menunggu Pembayaran: status='awaiting_payment' (customer should pay)
// 2. Pembayaran Dikirim: payment.verificationStatus == 'pending' (proof uploaded)
// 3. Pesanan Saya: status in ['booked','ongoing'] (confirmed / paid)
// 4. Dibatalkan: status='cancelled'
// Clicking an "awaiting_payment" or "payment_pending" card opens the Payment screen directly.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:geges_smartbarber/services/booking_anti_duplicate_service.dart';

class MyBookingsScreenImproved extends StatefulWidget {
  const MyBookingsScreenImproved({super.key});

  @override
  State<MyBookingsScreenImproved> createState() =>
      _MyBookingsScreenImprovedState();
}

class _MyBookingsScreenImprovedState extends State<MyBookingsScreenImproved>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late BookingAntiDuplicateService _antiDupService;

  final List<String> _tabs = [
    'Menunggu Pembayaran',
    'Pembayaran Dikirim',
    'Terbayar',
    'Dibatalkan',
  ];

  final List<String> _filterTypes = [
    'awaiting_payment',
    'payment_pending',
    'booked',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _antiDupService = BookingAntiDuplicateService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Saya')),
        body: const Center(child: Text('User tidak authenticated')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Saya'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amber,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(
          _tabs.length,
          (index) => _buildTabContent(user.uid, _filterTypes[index]),
        ),
      ),
    );
  }

  Widget _buildTabContent(String userId, String filterType) {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _antiDupService.streamCustomerBookingsFiltered(
        userId: userId,
        filterType: filterType,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Tidak ada booking',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: bookings.length,
          itemBuilder: (context, i) => _buildBookingCard(bookings[i]),
        );
      },
    );
  }

  Widget _buildBookingCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bookingId = doc.id;
    final status = data['status'] as String? ?? '-';
    final payment = Map<String, dynamic>.from(data['payment'] ?? {});
    final verificationStatus = payment['verificationStatus'] as String?;
    final totalPrice = payment['amount'] as int? ?? 0;
    final scheduledAt = data['scheduledAt'] as Timestamp?;
    final createdAt = data['createdAt'] as Timestamp?;

    String statusLabel = '';
    Color statusColor = Colors.grey;

    switch (status) {
      case 'awaiting_payment':
        if (verificationStatus == null) {
          statusLabel = 'Menunggu Pembayaran';
          statusColor = Colors.orange;
        }
        break;

      case 'booked':
      case 'ongoing':
        statusLabel = 'Terbayar';
        statusColor = Colors.green;
        break;

      case 'cancelled':
        statusLabel = 'Dibatalkan';
        statusColor = Colors.red;
        break;

      default:
        statusLabel = status;
    }

    if (verificationStatus == 'pending') {
      statusLabel = 'Pembayaran Dikirim (Menunggu Verifikasi)';
      statusColor = Colors.amber;
    }

    final card = GestureDetector(
      onTap: () {}, // No action on tap for awaiting_payment
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
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
                        Text(
                          'Booking ID: $bookingId',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (scheduledAt != null)
                          Text(
                            'Jadwal: ${DateFormat('dd MMM yyyy, HH:mm').format(scheduledAt.toDate())}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      statusLabel,
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor: statusColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: Rp ${NumberFormat('#,###', 'id_ID').format(totalPrice)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (createdAt != null)
                    Text(
                      'Dibuat: ${DateFormat('dd MMM HH:mm').format(createdAt.toDate())}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Tampilkan info payment jika ada
              if (payment.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (payment['proofUrl'] != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Bukti Dikirim',
                              style: TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      if (payment['proofLocked'] == true)
                        Row(
                          children: [
                            const Icon(
                              Icons.lock,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Upload Terkunci',
                              style: TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return card;
  }
}
