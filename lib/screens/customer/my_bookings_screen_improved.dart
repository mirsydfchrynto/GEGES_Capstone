// lib/screens/customer/my_bookings_screen_improved.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geges_smartbarber/services/booking_anti_duplicate_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/models/service.dart' as model;
import 'package:geges_smartbarber/screens/customer/booking_detail_screen.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kSuccess = Color(0xFF4CAF50);

class MyBookingsScreenImproved extends StatefulWidget {
  const MyBookingsScreenImproved({super.key});
  @override State<MyBookingsScreenImproved> createState() => _MyBookingsScreenImprovedState();
}

class _MyBookingsScreenImprovedState extends State<MyBookingsScreenImproved> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late BookingAntiDuplicateService _antiDupService;
  final BarbershopService _barbershopService = BarbershopService();
  final List<String> _tabs = ['Belum Bayar', 'Terjadwal', 'Sedang Proses', 'Riwayat'];
  final List<String> _filterTypes = ['awaiting_payment', 'scheduled', 'ongoing', 'history'];

  @override void initState() { super.initState(); _tabController = TabController(length: _tabs.length, vsync: this); _antiDupService = BookingAntiDuplicateService(); }
  @override void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('User tidak authenticated')));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Pesanan Saya', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.black, elevation: 0, bottom: TabBar(controller: _tabController, isScrollable: true, indicatorColor: kBrownAccent, labelColor: kBrownAccent, unselectedLabelColor: Colors.white38, labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), tabs: _tabs.map((tab) => Tab(text: tab)).toList())),
      body: TabBarView(controller: _tabController, children: List.generate(_tabs.length, (index) => _buildTabContent(user.uid, _filterTypes[index]))),
    );
  }

  Widget _buildTabContent(String userId, String filterType) {
    return StreamBuilder<List<DocumentSnapshot>>(stream: _antiDupService.streamCustomerBookingsFiltered(userId: userId, filterType: filterType), builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kBrownAccent));
      final bookings = snapshot.data ?? [];
      if (bookings.isEmpty) return _buildEmpty(filterType);
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: bookings.length, itemBuilder: (context, i) => _BookingCard(doc: bookings[i], barbershopService: _barbershopService));
    });
  }

  Widget _buildEmpty(String f) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.white10), const SizedBox(height: 16), Text('Belum ada pesanan', style: const TextStyle(color: Colors.white38))]));
}

class _BookingCard extends StatelessWidget {
  final DocumentSnapshot doc; final BarbershopService barbershopService; final QueueService _queueService = QueueService();
  _BookingCard({required this.doc, required this.barbershopService});

  @override Widget build(BuildContext context) {
    return StreamBuilder<Queue?>(stream: _queueService.streamQueueById(doc.id), builder: (context, snapshot) {
      final q = snapshot.data ?? Queue.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      final bool hasPaid = q.paymentProofBase64 != null && q.paymentProofBase64!.isNotEmpty;
      final bool isExpired = q.paymentDeadline != null && DateTime.now().isAfter(q.paymentDeadline!.toDate());
      return FutureBuilder(future: Future.wait([barbershopService.getBarbershopById(q.barbershopId), barbershopService.getBarbermanById(q.barbermanId), _loadServices(q.serviceIds ?? [])]), builder: (context, AsyncSnapshot<List<dynamic>> meta) {
        final shop = meta.hasData ? meta.data![0] as Barbershop? : null; final barber = meta.hasData ? meta.data![1] as Barberman? : null; final services = meta.hasData ? meta.data![2] as List<model.Service>? ?? [] : <model.Service>[];
        return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(queueId: q.id))), child: Container(margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.05))), child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: kBrownAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(DateFormat('dd').format(q.bookingTime.toDate()), style: const TextStyle(color: kBrownAccent, fontSize: 18, fontWeight: FontWeight.bold)), Text(DateFormat('MMM').format(q.bookingTime.toDate()).toUpperCase(), style: const TextStyle(color: kBrownAccent, fontSize: 10, fontWeight: FontWeight.bold))])), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(DateFormat('EEEE, HH:mm').format(q.bookingTime.toDate()), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)), Text(shop?.name ?? '...', style: const TextStyle(color: Colors.white38, fontSize: 12))])), _status(q, hasPaid, isExpired)])),
          const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [CircleAvatar(radius: 15, backgroundColor: kBrownAccent.withValues(alpha: 0.2), backgroundImage: barber?.imageUrl != null ? NetworkImage(barber!.imageUrl!) : null, child: barber?.imageUrl == null ? const Icon(Icons.person, size: 16, color: kBrownAccent) : null), const SizedBox(width: 10), Text(barber?.name ?? 'Assigned by System', style: const TextStyle(color: Colors.white70, fontSize: 13)), const Spacer(), Text(services.isEmpty ? '...' : (services.length > 1 ? '${services[0].name} +${services.length - 1}' : services[0].name), style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic))])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Rp ${NumberFormat('#,###', 'id_ID').format(q.totalPrice ?? 0)}', style: const TextStyle(color: kBrownAccent, fontWeight: FontWeight.w900, fontSize: 17)), (q.status == QueueStatus.awaitingPayment && !hasPaid && !isExpired) ? ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(orderId: q.id, totalPrice: q.totalPrice ?? 0))), style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('BAYAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))) : const Text('Lihat Detail', style: TextStyle(color: Colors.white24, fontSize: 11))]))
        ])));
      });
    });
  }

  Future<List<model.Service>> _loadServices(List<String> ids) async { if (ids.isEmpty) return []; final all = await barbershopService.getAllServices(); return all.where((s) => ids.contains(s.id)).toList(); }

  Widget _status(Queue q, bool paid, bool exp) {
    String l = 'BELUM BAYAR'; Color c = Colors.orange;
    if (exp && !paid && q.status == QueueStatus.awaitingPayment) { l = 'KADALUARSA'; c = Colors.red; }
    else if (q.status == QueueStatus.cancelled) { l = 'DIBATALKAN'; c = Colors.red; }
    else if (q.status == QueueStatus.served) { l = 'SELESAI'; c = kSuccess; }
    else if (q.status == QueueStatus.ongoing) { l = 'SEDANG DIPROSES'; c = Colors.blue; }
    else if (q.status == QueueStatus.booked) { l = 'TERJADWAL'; l = 'TERJADWAL'; c = kSuccess; }
    else if (paid && (q.verifiedBy == null || q.verifiedBy!.isEmpty)) { l = 'MENUNGGU VERIFIKASI'; c = Colors.amber; }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.3))), child: Text(l, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)));
  }
}