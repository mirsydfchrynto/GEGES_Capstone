// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/screens/auth/login_screen.dart';
import 'package:geges_smartbarber/screens/admin/live_queue_screen.dart';
import 'package:geges_smartbarber/screens/admin/_manual_booking_form.dart';
import 'package:geges_smartbarber/screens/admin/payment_verification_screen_improved.dart';
import 'package:geges_smartbarber/screens/admin/service_management_screen.dart';
import 'package:geges_smartbarber/screens/admin/barber_management_screen.dart';
import 'package:geges_smartbarber/screens/admin/cancellation_requests_screen.dart';
import 'package:geges_smartbarber/screens/admin/barbershop_settings_screen.dart';
import 'package:geges_smartbarber/screens/admin/barbershop_gallery_screen.dart';
import 'package:geges_smartbarber/screens/admin/account_management_screen.dart';
import 'package:geges_smartbarber/screens/admin/sales_report_screen.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkSurface = Color(0xFF1E1E1E);
const Color kBlack = Colors.black;
const Color kRedNotification = Color(0xFFFF3B30);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final QueueService _queueService = QueueService();
  final BarbershopService _barbershopService = BarbershopService();
  final AuthService _authService = AuthService();

  final String? _adminUid = FirebaseAuth.instance.currentUser?.uid;
  String? _adminBarbershopId;
  String _barbershopName = "Loading...";
  String _loadingError = '';
  bool _isShopOpen = false;
  bool _isTogglingStatus = false;
  Timer? _autoCancelTimer;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    _autoCancelTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_adminBarbershopId != null) _queueService.cancelExpiredBookings(_adminBarbershopId!);
    });
  }

  @override
  void dispose() { _autoCancelTimer?.cancel(); super.dispose(); }

  Future<void> _loadAdminData() async {
    if (_adminUid == null) { _logout(context); return; }
    try {
      final adminData = await _authService.getUserById(_adminUid);
      if (adminData == null) { if (mounted) setState(() => _loadingError = 'ERROR: Admin tidak ditemukan.'); return; }
      final barbershopId = adminData.barbershopId;
      if (barbershopId == null || barbershopId.isEmpty) { if (mounted) setState(() => _loadingError = 'ERROR: Admin tidak terikat Barbershop.'); return; }
      final barbershop = await _barbershopService.getBarbershopById(barbershopId);
      if (mounted) {
        setState(() {
          _adminBarbershopId = barbershopId;
          _barbershopName = barbershop?.name ?? 'Barbershop Unknown';
          _isShopOpen = barbershop?.isOpen ?? false;
          _loadingError = '';
        });
      }
    } catch (e) { if (mounted) setState(() => _loadingError = 'FATAL ERROR: $e'); }
  }

  void _logout(BuildContext context) async {
    await _authService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
  }

  Future<void> _toggleShopStatus() async {
    if (_adminBarbershopId == null || _isTogglingStatus) return;
    setState(() => _isTogglingStatus = true);
    try {
      await _barbershopService.updateShopStatus(_adminBarbershopId!, !_isShopOpen);
      if (mounted) {
        setState(() { _isShopOpen = !_isShopOpen; _isTogglingStatus = false; });
      }
    } catch (e) { if (mounted) setState(() => _isTogglingStatus = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingError.isNotEmpty) return Scaffold(backgroundColor: kBlack, body: Center(child: Text(_loadingError, style: const TextStyle(color: Colors.red))));
    if (_adminBarbershopId == null) return const Scaffold(backgroundColor: kBlack, body: Center(child: CircularProgressIndicator(color: kBrownAccent)));

    final stream = _queueService.streamQueuesForBarbershop(_adminBarbershopId!, statusFilter: ['waiting', 'awaiting_payment', 'booked', 'ongoing', 'served', 'cancelled', 'cancellation_requested'], limit: 30);

    return Scaffold(
      backgroundColor: kBlack,
      body: StreamBuilder<List<Queue>>(
        stream: stream,
        builder: (context, snapshot) {
          final allQueues = snapshot.data ?? [];
          final stats = _calculateStats(allQueues);
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async => _loadAdminData(),
              color: kBrownAccent,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 20),
                  _buildShopToggle(),
                  const SizedBox(height: 20),
                  _buildRealtimeStatsRow(stats),
                  const SizedBox(height: 24),
                  const Text('Main Menu', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildGridMenu(stats),
                  const SizedBox(height: 24),
                  _buildUpcomingAppointment(allQueues),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, int> _calculateStats(List<Queue> queues) {
    final DateTime now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final todayQueues = queues.where((q) {
      final d = q.bookingTime.toDate();
      return d.isAfter(todayStart.subtract(const Duration(seconds: 1))) && d.isBefore(todayEnd);
    }).toList();

    return {
      'pending_payment': queues.where((q) => q.status == QueueStatus.awaitingPayment && (q.paymentProofBase64 == null || q.paymentProofBase64!.isEmpty)).length,
      'verify_payment': queues.where((q) => q.status == QueueStatus.awaitingPayment && q.paymentProofBase64 != null && q.paymentProofBase64!.isNotEmpty).length,
      'cancellation_req': queues.where((q) => q.status == QueueStatus.cancellationRequested).length,
      'today_booked': todayQueues.where((q) => q.status == QueueStatus.booked).length,
      'today_ongoing': todayQueues.where((q) => q.status == QueueStatus.ongoing).length,
      'today_served': todayQueues.where((q) => q.status == QueueStatus.served).length,
      'today_cancelled': todayQueues.where((q) => q.status == QueueStatus.cancelled).length,
    };
  }

  Widget _buildTopBar() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_barbershopName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        const Text('Admin Dashboard', style: TextStyle(color: Colors.white54, fontSize: 14)),
      ]),
      IconButton(onPressed: () => _logout(context), icon: const Icon(Icons.logout, color: Colors.white54)),
    ]);
  }

  Widget _buildShopToggle() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: kDarkSurface, borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: _isShopOpen ? Colors.green : Colors.red, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Text(_isShopOpen ? 'TOKO BUKA' : 'TOKO TUTUP', style: TextStyle(color: _isShopOpen ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
      Switch(value: _isShopOpen, onChanged: _isTogglingStatus ? null : (_) => _toggleShopStatus(), activeThumbColor: Colors.green, activeTrackColor: Colors.green.withValues(alpha: 0.3), inactiveThumbColor: Colors.red, inactiveTrackColor: Colors.red.withValues(alpha: 0.3)),
    ]));
  }

  Widget _buildRealtimeStatsRow(Map<String, int> stats) {
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
      _statChip('Unpaid', stats['pending_payment']!, Colors.amber), const SizedBox(width: 12),
      _statChip('Verify', stats['verify_payment']!, Colors.blueAccent), const SizedBox(width: 12),
      _statChip('Booked', stats['today_booked']!, Colors.lightBlue), const SizedBox(width: 12),
      _statChip('Active', stats['today_ongoing']!, Colors.greenAccent), const SizedBox(width: 12),
      _statChip('Done', stats['today_served']!, Colors.grey), const SizedBox(width: 12),
      _statChip('Cancel', stats['today_cancelled']!, Colors.redAccent),
    ]));
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))), child: Column(children: [
      Text(count.toString(), style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12)),
    ]));
  }

  Widget _buildGridMenu(Map<String, int> stats) {
    return GridView.count(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: [
      _menuItem(Icons.verified_user_outlined, 'Verifikasi Bayar', 'Pembayaran Masuk', () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentVerificationScreenImproved(barbershopId: _adminBarbershopId))), badge: stats['verify_payment']!),
      _menuItem(Icons.playlist_add_check, 'Live Queue', 'Antrean Hari Ini', () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveQueueScreen(barbershopId: _adminBarbershopId!, initialFilter: ['booked', 'ongoing'], title: 'Antrean Live'))), badge: stats['today_booked']! + stats['today_ongoing']!),
      _menuItem(Icons.cancel_presentation, 'Request Batal', 'Pengajuan Refund', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CancellationRequestsScreen(currentUserId: _adminUid))), badge: stats['cancellation_req']!),
      _menuItem(Icons.add_circle_outline, 'Booking Manual', 'Input Offline', _goToManualBooking),
      _menuItem(Icons.people_outline, 'Karyawan', 'Manage Staff', () => Navigator.push(context, MaterialPageRoute(builder: (_) => BarberManagementScreen(barbershopId: _adminBarbershopId!)))),
      _menuItem(Icons.cut_outlined, 'Layanan', 'Manage Service', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceManagementScreen(barbershopId: _adminBarbershopId!)))),
      _menuItem(Icons.storefront, 'Profil Toko', 'Settings', () async {
        final shop = await _barbershopService.getBarbershopById(_adminBarbershopId!);
        if (shop != null && mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => BarbershopSettingsScreen(barbershop: shop)));
      }),
      _menuItem(Icons.photo_library, 'Galeri Album', 'Manage Photos', () async {
        final shop = await _barbershopService.getBarbershopById(_adminBarbershopId!);
        if (shop != null && mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => BarbershopGalleryScreen(barbershop: shop)));
      }),
      _menuItem(Icons.analytics_outlined, 'Laporan Penjualan', 'Revenue Report', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SalesReportScreen(barbershopId: _adminBarbershopId!)))),
      _menuItem(Icons.manage_accounts_outlined, 'Akun Saya', 'Edit Profile', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountManagementScreen(userId: _adminUid!)))),
    ]);
  }

  Widget _menuItem(IconData icon, String title, String sub, VoidCallback onTap, {int badge = 0}) {
    return Stack(clipBehavior: Clip.none, children: [
      InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kDarkSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(icon, color: kBrownAccent, size: 28),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ])
      ]))),
      if (badge > 0) Positioned(top: -5, right: -5, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: kRedNotification, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))]), constraints: const BoxConstraints(minWidth: 24, minHeight: 24), child: Center(child: Text(badge > 99 ? '99+' : badge.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
    ]);
  }

  void _goToManualBooking() async {
    final barbershop = await _barbershopService.getBarbershopById(_adminBarbershopId!);
    if (barbershop != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Input Booking Offline'), backgroundColor: kBlack), backgroundColor: kBlack, body: ManualBookingForm(barbershop: barbershop, queueService: _queueService))));
    }
  }

  Widget _buildUpcomingAppointment(List<Queue> queues) {
    final now = DateTime.now();
    final active = queues.where((q) => q.status == QueueStatus.booked || q.status == QueueStatus.ongoing).toList();
    final todayUpcoming = active.where((q) { final d = q.bookingTime.toDate(); return d.year == now.year && d.month == now.month && d.day == now.day && d.isAfter(now.subtract(const Duration(minutes: 30))); }).toList();
    todayUpcoming.sort((a, b) => a.bookingTime.toDate().compareTo(b.bookingTime.toDate()));
    Queue? next; bool isToday = false;
    if (todayUpcoming.isNotEmpty) { next = todayUpcoming.first; isToday = true; } else {
      final futureUpcoming = active.where((q) => q.bookingTime.toDate().isAfter(now)).toList();
      futureUpcoming.sort((a, b) => a.bookingTime.toDate().compareTo(b.bookingTime.toDate()));
      if (futureUpcoming.isNotEmpty) { next = futureUpcoming.first; isToday = false; }
    }
    if (next == null) return const SizedBox();
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [kBrownAccent.withValues(alpha: 0.2), kDarkSurface]), borderRadius: BorderRadius.circular(16), border: Border.all(color: kBrownAccent.withValues(alpha: 0.3))), child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kBrownAccent.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.notifications_active, color: kBrownAccent)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isToday ? "Jadwal Berikutnya (Hari Ini)" : "Jadwal Mendatang", style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(isToday ? DateFormat('HH:mm').format(next.bookingTime.toDate()) : DateFormat('dd MMM, HH:mm').format(next.bookingTime.toDate()), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(next.status == QueueStatus.ongoing ? "Sedang Berlangsung" : "Siap Dilayani", style: TextStyle(color: next.status == QueueStatus.ongoing ? Colors.green : Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12))
      ])),
    ]));
  }
}