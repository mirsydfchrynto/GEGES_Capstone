// lib/screens/admin/booking_requests_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;

class BookingRequestsScreen extends StatefulWidget {
  const BookingRequestsScreen({super.key});

  @override
  State<BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends State<BookingRequestsScreen> {
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

  Future<String> _getBarbermanName(String id) async {
    if (_nameCache.containsKey('bm_$id')) return _nameCache['bm_$id']!;
    try {
      final doc = await _firestore.collection('barbermen').doc(id).get();
      final name = doc.data()?['name'] ?? 'Barberman';
      _nameCache['bm_$id'] = name;
      return name;
    } catch (_) {
      return 'Barberman';
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

  Future<String> _getBarbershopImage(String id) async {
    const String defaultImage = 'https://cdn-icons-png.flaticon.com/512/706/706830.png';
    if (_nameCache.containsKey('img_$id')) return _nameCache['img_$id']!;
    try {
      final doc = await _firestore.collection('barbershops').doc(id).get();
      final image = doc.data()?['imageUrl'] ?? defaultImage;
      _nameCache['img_$id'] = image;
      return image;
    } catch (_) {
      return defaultImage;
    }
  }

  Future<Map<String, dynamic>> _fetchDetails(Queue q) async {
    final results = await Future.wait([
      _getCustomerName(q.customerId),
      _getBarbershopName(q.barbershopId),
      _getBarbermanName(q.barbermanId),
      _getServiceNames(q.serviceIds),
      _getBarbershopImage(q.barbershopId),
    ]);
    return {
      'customer': results[0],
      'shop': results[1],
      'barber': results[2],
      'service': results[3],
      'image': results[4],
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
        title: const Text('Booking Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: StreamBuilder<List<Queue>>(
        stream: _queueService.streamAllQueues(statusFilter: ['waiting']),
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
                Icon(Icons.inbox, color: kTextGrey, size: 60),
                SizedBox(height: 16),
                Text('Tidak ada booking pending', style: TextStyle(color: kTextGrey))
              ]),
            );
          }

          requests.sort((a, b) => b.bookingTime.compareTo(a.bookingTime));

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
            height: 160,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: kDarkGrey, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: CircularProgressIndicator(color: kBrownAccent)),
          );
        }

        final d = snapshot.data!;
        return GestureDetector(
          onTap: () => _showDetail(context, q, d),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: kDarkGrey, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 130,
                      width: double.infinity,
                      color: Colors.grey[900],
                      child: CachedNetworkImage(imageUrl: d['image'], fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.storefront, color: kTextGrey)),
                    ),
                    Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(16)), child: const Text('PENDING', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['shop'], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(children: [const Icon(Icons.person, size: 11, color: kTextGrey), const SizedBox(width: 3), Expanded(child: Text(d['customer'], style: const TextStyle(color: kTextGrey, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                    const SizedBox(height: 2),
                    Row(children: [const Icon(Icons.access_time, size: 11, color: kTextGrey), const SizedBox(width: 3), Text(_formatTs(q.bookingTime), style: const TextStyle(color: kTextGrey, fontSize: 10))]),
                    if (q.totalPrice != null) ...[const SizedBox(height: 2), Row(children: [const Icon(Icons.money, size: 11, color: kBrownAccent), const SizedBox(width: 3), Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(q.totalPrice), style: const TextStyle(color: kBrownAccent, fontSize: 10, fontWeight: FontWeight.bold))])]
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, Queue q, Map<String, dynamic> d) {
    final noteCtrl = TextEditingController();
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
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), GestureDetector(onTap: () => Navigator.pop(c), child: const Icon(Icons.close, color: Colors.white))]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Status', 'PENDING', Colors.orange),
                    _row('Customer', d['customer']),
                    _row('Shop', d['shop']),
                    _row('Barber', d['barber']),
                    _row('Service', d['service']),
                    _row('Time', _formatTs(q.bookingTime)),
                    if (q.estimatedDuration != null) _row('Duration', '${q.estimatedDuration} min'),
                    if (q.totalPrice != null) _row('Price', NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(q.totalPrice), kBrownAccent),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Notes (optional)', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 6),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'E.g. Barberman busy, conflict schedule',
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: () async { try { await _queueService.adminRejectRequest(q.id, rejectionReason: noteCtrl.text.trim().isEmpty ? 'Rejected' : noteCtrl.text.trim()); if (c.mounted) { Navigator.pop(c); ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Request rejected'), backgroundColor: Colors.red)); } } catch (e) { ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('Error: $e'))); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size.fromHeight(44)), child: const Text('Reject'))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton(onPressed: () async { try { await _queueService.adminConfirmRequest(q.id); if (c.mounted) { Navigator.pop(c); ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Booking confirmed'), backgroundColor: Colors.green)); } } catch (e) { ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('Error: $e'))); } }, style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, minimumSize: const Size.fromHeight(44)), child: const Text('Approve'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String val, [Color? color]) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: kTextGrey, fontSize: 12)), Text(val, style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w600))]));
  }

  String _formatTs(Timestamp ts) => DateFormat('EEE d MMM HH:mm').format(ts.toDate());
}
