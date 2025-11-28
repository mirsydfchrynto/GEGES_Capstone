// lib/screens/customer/tabs/my_bookings_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import '../booking_detail_screen.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final QueueService _queueService = QueueService();
  final String? _customerId = FirebaseAuth.instance.currentUser?.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _nameCache = {};
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // On screen init, trigger cancel checks for expired waiting / awaiting_payment
    if (_customerId != null) {
      // best-effort: cancel any expired requests (waiting) and expired awaiting payments
      _queueService.cancelExpiredWaitingQueuesForCustomer(_customerId).then((c) => debugPrint('cancelled waiting: $c')).catchError((e) => debugPrint('cancelWaiting err: $e'));
      _queueService.cancelExpiredAwaitingPaymentQueuesForCustomer(_customerId).then((c) => debugPrint('cancelled awaiting: $c')).catchError((e) => debugPrint('cancelAwaiting err: $e'));
    }
  }

  Future<void> _handleRefresh() async {
    // Manual refresh: trigger expiry checks and rebuild stream
    if (_customerId != null) {
      try {
        await Future.wait([
          _queueService.cancelExpiredWaitingQueuesForCustomer(_customerId),
          _queueService.cancelExpiredAwaitingPaymentQueuesForCustomer(_customerId),
        ]);
      } catch (e) {
        debugPrint('Refresh error: $e');
      }
    }
    // StreamBuilder will rebuild automatically
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _getBarbershopName(String barbershopId) async {
    if (_nameCache.containsKey('bs_$barbershopId')) {
      return _nameCache['bs_$barbershopId']!;
    }
    try {
      final doc = await _firestore.collection('barbershops').doc(barbershopId).get();
      final name = doc.data()?['name'] ?? 'Barbershop Dihapus';
      _nameCache['bs_$barbershopId'] = name;
      return name;
    } catch (_) {
      return 'Barbershop Dihapus';
    }
  }

  Future<String> _getBarbermanName(String barbermanId) async {
    if (_nameCache.containsKey('bm_$barbermanId')) {
      return _nameCache['bm_$barbermanId']!;
    }
    try {
      final doc = await _firestore.collection('barbermen').doc(barbermanId).get();
      final name = doc.data()?['name'] ?? 'Barberman Dihapus';
      _nameCache['bm_$barbermanId'] = name;
      return name;
    } catch (_) {
      return 'Barberman Dihapus';
    }
  }

  Future<String> _getServiceNames(List<String> serviceIds) async {
    if (serviceIds.isEmpty) return 'Layanan Tidak Tersedia';
    try {
      final docs = await Future.wait(
        serviceIds.map((id) => _firestore.collection('services').doc(id).get()),
      );
      final names = docs
          .where((doc) => doc.exists)
          .map((doc) => doc.data()?['name'] as String? ?? 'Layanan')
          .toList();
      if (names.isEmpty) return 'Layanan Tidak Tersedia';
      if (names.length == 1) return names[0];
      return '${names[0]} (+${names.length - 1})';
    } catch (_) {
      return 'Layanan Tidak Tersedia';
    }
  }

  Future<String> _getBarbershopImage(String barbershopId) async {
    const String defaultImage = 'https://cdn-icons-png.flaticon.com/512/706/706830.png';
    if (_nameCache.containsKey('img_$barbershopId')) {
      return _nameCache['img_$barbershopId']!;
    }
    try {
      final doc = await _firestore.collection('barbershops').doc(barbershopId).get();
      final image = doc.data()?['imageUrl'] ?? defaultImage;
      _nameCache['img_$barbershopId'] = image;
      return image;
    } catch (_) {
      return defaultImage;
    }
  }

  String _formatStatusForQueue(Queue queue) {
    // If admin has approved request and payment deadline exists => awaiting payment
    if ((queue.requestStatus == RequestStatus.approved) && queue.paymentDeadline != null) {
      return 'Menunggu Pembayaran';
    }

    switch (queue.status) {
      case QueueStatus.waiting:
        return 'Menunggu Konfirmasi';
      case QueueStatus.booked:
        return 'Booked';
      case QueueStatus.ongoing:
        return 'Sedang Berlangsung';
      case QueueStatus.served:
        return 'Selesai';
      case QueueStatus.cancelled:
        return 'Dibatalkan';
    }
  }

  Color _getStatusColor(QueueStatus status) {
    switch (status) {
      case QueueStatus.waiting:
        return Colors.orange;
      case QueueStatus.booked:
        return kBrownAccent;
      case QueueStatus.ongoing:
        return Colors.blue;
      case QueueStatus.served:
        return Colors.green;
      case QueueStatus.cancelled:
        return Colors.red;
    }
  }

  Future<Map<String, dynamic>> _fetchQueueDetails(Queue queue) async {
    final results = await Future.wait([
      _getBarbershopName(queue.barbershopId),
      _getBarbermanName(queue.barbermanId),
      _getServiceNames(queue.serviceIds ?? []),
      _getBarbershopImage(queue.barbershopId),
    ]);

    return {
      'barbershopName': results[0],
      'barbermanName': results[1],
      'serviceName': results[2],
      'image': results[3],
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
        title: const Text('My Bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kBrownAccent,
          labelColor: kBrownAccent,
          unselectedLabelColor: kTextGrey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _handleRefresh,
        color: kBrownAccent,
        backgroundColor: kDarkGrey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildBookingList(isCompleted: false),
            _buildBookingList(isCompleted: true),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingList({required bool isCompleted}) {
    if (_customerId == null) {
      return const Center(child: Text('Anda harus login', style: TextStyle(color: kTextGrey)));
    }

    final List<String> requiredStatus = isCompleted
        ? ['served', 'cancelled', 'refund_pending']
        : ['waiting', 'booked', 'ongoing', 'cancellation_requested'];

    final Stream<List<Queue>> queueStream =
        _queueService.streamQueuesForCustomer(_customerId, statusFilter: requiredStatus);

    return StreamBuilder<List<Queue>>(
      stream: queueStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kBrownAccent));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        final filteredList = snapshot.data ?? [];
        if (filteredList.isEmpty) {
          return _buildEmptyState(isCompleted);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredList.length,
          itemBuilder: (context, index) => _buildBookingCard(context, filteredList[index]),
          physics: const AlwaysScrollableScrollPhysics(),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isCompleted) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 100),
            Icon(isCompleted ? Icons.history : Icons.calendar_month, color: kTextGrey, size: 60),
            const SizedBox(height: 16),
            Text(
              isCompleted ? 'Tidak ada riwayat booking.' : 'Anda tidak memiliki booking aktif.',
              style: const TextStyle(color: kTextGrey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, Queue queue) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchQueueDetails(queue),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: kDarkGrey, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: CircularProgressIndicator(color: kBrownAccent)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kDarkGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red),
            ),
            child: Text('Error loading: ${queue.id}', style: const TextStyle(color: Colors.red)),
          );
        }

        final details = snapshot.data!;
        final statusColor = _getStatusColor(queue.status);

        return GestureDetector(
          onTap: () => _showBookingDetail(context, queue, details),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: kDarkGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image header
                Stack(
                  children: [
                    Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.grey[900],
                      child: CachedNetworkImage(
                        imageUrl: details['image'] ?? '',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.storefront, color: kTextGrey, size: 60),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          _formatStatusForQueue(queue),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details['barbershopName'] ?? 'Loading',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow('Layanan', details['serviceName'] ?? 'Loading'),
                      const SizedBox(height: 6),
                      _buildDetailRow('Barberman', details['barbermanName'] ?? 'Loading'),
                      const SizedBox(height: 6),
                      _buildDetailRow('Waktu', _formatTimestamp(queue.bookingTime)),
                      if (queue.totalPrice != null) ...[
                        const SizedBox(height: 6),
                        _buildDetailRow(
                          'Total',
                          NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(queue.totalPrice),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: kTextGrey, fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showBookingDetail(BuildContext context, Queue queue, Map<String, dynamic> details) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingDetailScreen(queueId: queue.id)),
    );
  }

  String _formatTimestamp(Timestamp ts) {
    return DateFormat('EEE, d MMM HH:mm').format(ts.toDate());
  }
}
