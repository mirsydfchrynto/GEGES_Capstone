// lib/screens/admin/admin_dashboard_screen.dart (FINAL - adjusted booking counters)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/screens/login_screen.dart';
import 'package:geges_smartbarber/screens/admin/live_queue_screen.dart';
import 'package:geges_smartbarber/screens/admin/_manual_booking_form.dart';
import 'package:geges_smartbarber/screens/admin/payment_verification_screen_improved.dart'; // Corrected import
import 'package:geges_smartbarber/screens/admin/barber_management_screen.dart'; // Fixed import name
import 'package:geges_smartbarber/screens/admin/service_management_screen.dart'; // Added import
import 'package:geges_smartbarber/screens/admin/send_notification_screen.dart';
import 'package:geges_smartbarber/screens/admin/cancellation_requests_screen.dart';

// --- THEME COLORS ---
const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkSurface = Color(0xFF1E1E1E);
const Color kBlack = Colors.black;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Services
  final QueueService _queueService = QueueService();
  final BarbershopService _barbershopService = BarbershopService();
  final AuthService _authService = AuthService();

  // State Data
  final String? _adminUid = FirebaseAuth.instance.currentUser?.uid;
  String? _adminBarbershopId;
  String _barbershopName = "Loading...";
  String _loadingError = '';

  // NEW: Barbershop Status State
  bool _isShopOpen = false;
  bool _isTogglingStatus = false; // Prevent double toggle

  // Manual refresh control
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    if (_adminUid == null) {
      _logout(context);
      return;
    }

    try {
      final adminData = await _authService.getUserById(_adminUid);

      if (adminData == null) {
        if (mounted) {
          setState(() {
            _loadingError =
                'ERROR: Akun Admin ID ($_adminUid) tidak ditemukan di koleksi "users".';
          });
        }
        return;
      }

      // Accept multiple admin role variants to be robust against inconsistent DB values
      if (!(adminData.role == 'admin_owner' ||
          adminData.role == 'owner' ||
          adminData.role == 'admin')) {
        if (mounted) {
          setState(() {
            _loadingError =
                'ERROR: Akses ditolak. Role Anda: ${adminData.role}.';
          });
        }
        return;
      }

      final barbershopId = adminData.barbershopId;
      if (barbershopId == null || barbershopId.isEmpty) {
        if (mounted) {
          setState(() {
            _loadingError =
                'ERROR: Admin ${adminData.name} tidak terikat pada Barbershop manapun.';
          });
        }
        return;
      }

      final barbershop = await _getBarbershopSafe(barbershopId);

      if (mounted) {
        setState(() {
          _adminBarbershopId = barbershopId;
          _barbershopName = barbershop?.name ?? 'Barbershop Unknown';
          _isShopOpen = barbershop?.isOpen ?? false;
          _loadingError = '';
        });
      }
    } catch (e) {
      debugPrint("FATAL LOAD ERROR: $e");
      if (mounted) {
        setState(() {
          _loadingError =
              'FATAL ERROR: Gagal memuat data dasar: ${e.toString()}. Cek service logs.';
        });
      }
    }
  }

  Future<Barbershop?> _getBarbershopSafe(String id) {
    if (id.isEmpty) return Future.value(null);
    return _barbershopService.getBarbershopById(id);
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _toggleShopStatus() async {
    if (_adminBarbershopId == null || _isTogglingStatus) return;

    setState(() {
      _isTogglingStatus = true;
    });

    try {
      await _barbershopService.updateShopStatus(
        _adminBarbershopId!,
        !_isShopOpen,
      );

      if (mounted) {
        setState(() {
          _isShopOpen = !_isShopOpen;
          _isTogglingStatus = false;
        });
        final statusText = _isShopOpen ? 'DIBUKA' : 'DITUTUP';
        _showSnackBar('Toko berhasil $statusText!');
      }
    } catch (e) {
      debugPrint("Failed to toggle shop status: $e");
      if (mounted) {
        setState(() {
          _isTogglingStatus = false;
        });
        _showSnackBar('Gagal update status toko: ${e.toString()}');
      }
    }
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kDarkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Konfirmasi Logout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari akun admin?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal', style: TextStyle(color: kBrownAccent)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Tutup dialog
                _logout(context); // Lanjutkan proses logout
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Manual refresh trigger (lightweight)
  Future<void> _manualRefresh() async {
    if (_adminBarbershopId == null) return;
    setState(() => _isRefreshing = true);
    try {
      // re-load admin data (barbershop metadata) and force small delay for UX
      await _loadAdminData();
      await Future.delayed(const Duration(milliseconds: 400));
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // Build helpers & small widgets
  Widget _buildHeader(
    BuildContext context, {
    required int todayBookingCount,
    required int pendingCount,
    required int completedCount,
  }) {
    final shopStatusText = _isShopOpen ? 'BUKA' : 'TUTUP';
    final shopStatusColor = _isShopOpen
        ? const Color(0xFF4CAF50)
        : const Color(0xFFD32F2F);

    // use explicit RGBA for brown accent tints (avoid withOpacity deprecated)
    final brown70 = const Color.fromRGBO(195, 164, 123, 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // row 1
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _barbershopName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: shopStatusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status Toko: $shopStatusText',
                        style: TextStyle(
                          color: shopStatusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Logout icon (compact)
            Container(
              decoration: BoxDecoration(
                color: kDarkSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.logout, color: kBrownAccent),
                onPressed: () => _showLogoutConfirmationDialog(context),
                tooltip: 'Logout',
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // row 2: toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kelola Toko',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kBlack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    shopStatusText,
                    style: TextStyle(
                      color: shopStatusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 20,
                    child: Switch(
                      value: _isShopOpen,
                      onChanged: _isTogglingStatus
                          ? null
                          : (_) => _toggleShopStatus(),
                      activeColor: const Color(0xFF388E3C),
                      inactiveThumbColor: const Color(0xFFD32F2F),
                      inactiveTrackColor: const Color.fromRGBO(255, 0, 0, 0.3),
                    ),
                  ),
                  if (_isTogglingStatus)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kBrownAccent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // stat cards (dihitung dari stream snapshot; nilai dikirim ke header)
        Row(
          children: [
            _buildStatCard(
              'Booking',
              todayBookingCount.toString(),
              Icons.calendar_today,
              brown70,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              'Waiting',
              pendingCount.toString(),
              Icons.pending,
              brown70,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              'Selesai',
              completedCount.toString(),
              Icons.check_circle_outline,
              brown70,
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Text(
          'Menu Utama',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    final border = BoxDecoration(
      color: kDarkSurface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Icon(icon, color: iconColor, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridMenu() {
    if (_adminBarbershopId == null) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // 'Konfirmasi Booking' has been removed in favor of 'Verifikasi Pembayaran'
        // Admin should verify payment from the "Verifikasi Pembayaran" menu.
        _buildMenuCard(
          Icons.playlist_add_check,
          'Antrean Live',
          'Booked & Ongoing',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LiveQueueScreen(
                  barbershopId: _adminBarbershopId!,
                  initialFilter: [
                    QueueStatus.booked.value,
                    QueueStatus.ongoing.value,
                  ],
                  title: 'Antrean Live',
                ),
              ),
            );
          },
        ),
        _buildMenuCard(
          Icons.payment,
          'Verifikasi Pembayaran',
          'Awaiting Payment',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PaymentVerificationScreenImproved(),
              ),
            );
          },
        ),
        _buildMenuCard(
          Icons.cancel_outlined,
          'Manajemen Pembatalan',
          'Refund Requests',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CancellationRequestsScreen(
                  currentUserId: _adminUid,
                ),
              ),
            );
          },
        ),
        _buildMenuCard(
          Icons.receipt_long,
          'Tambah Booking Manual',
          'Quick Entry',
          () async {
            if (_adminBarbershopId == null) {
              _showSnackBar('Barbershop belum terdeteksi.');
              return;
            }

            final barbershop = await _getBarbershopSafe(_adminBarbershopId!);
            if (barbershop == null) {
              _showSnackBar('Data barbershop tidak ditemukan.');
              return;
            }

            if (!mounted) return;

            // Navigate to a full-screen manual booking page using the existing ManualBookingForm
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    backgroundColor: kBrownAccent,
                    title: const Text(
                      'Tambah Booking Manual',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  backgroundColor: kBlack,
                  body: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ManualBookingForm(
                        barbershop: barbershop,
                        queueService: _queueService,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        _buildMenuCard(
          Icons.list_alt,
          'Lihat Semua Riwayat',
          'Archive & Report',
          () => _showSnackBar('Navigasi ke Semua Riwayat Booking'),
        ),
        _buildMenuCard(
          Icons.face_retouching_natural,
          'Kelola Karyawan',
          'Jadwal & Libur',
          () {
            if (_adminBarbershopId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BarberManagementScreen(
                    barbershopId: _adminBarbershopId!,
                  ),
                ),
              );
            }
          },
        ),
        _buildMenuCard(
          Icons.cut,
          'Kelola Layanan',
          'Harga & Durasi',
          () {
            if (_adminBarbershopId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ServiceManagementScreen(
                    barbershopId: _adminBarbershopId!,
                  ),
                ),
              );
            }
          },
        ),
        _buildMenuCard(
          Icons.star_half,
          'Lihat Ulasan',
          'Customer Feedback',
          () => _showSnackBar('Navigasi ke Kelola Ulasan'),
        ),
        _buildMenuCard(
          Icons.notifications_active,
          'Kirim Notifikasi',
          'Via Firestore',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SendNotificationScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final brownBorder = const Color.fromRGBO(195, 164, 123, 0.2);
    final brownBg = const Color.fromRGBO(195, 164, 123, 0.1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: kDarkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: brownBorder, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: brownBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: kBrownAccent, size: 30),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAppointment(List<Queue> allQueues) {
    final activeQueues = allQueues
        .where(
          (q) =>
              q.status == QueueStatus.waiting ||
              q.status == QueueStatus.booked ||
              q.status == QueueStatus.ongoing,
        )
        .toList();
    activeQueues.sort(
      (a, b) => a.bookingTime.toDate().compareTo(b.bookingTime.toDate()),
    );

    if (activeQueues.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(
          child: Text(
            'Tidak ada janji temu aktif saat ini.',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }

    final q = activeQueues.first;

    return FutureBuilder<String>(
      future: _getUpcomingDetails(q),
      builder: (context, snap) {
        final data =
            snap.data?.split('|') ??
            ['Pelanggan Loading...', 'Layanan Loading...'];
        final customerName = data[0];
        final serviceName = data[1];

        return Container(
          margin: const EdgeInsets.only(top: 25, bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: kDarkSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color.fromRGBO(195, 164, 123, 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Janji Temu Mendatang',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.white12, height: 25),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(195, 164, 123, 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: kBrownAccent,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          serviceName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(q.bookingTime.toDate()),
                        style: const TextStyle(
                          color: kBrownAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        q.status.value.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(q.status),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> _getUpcomingDetails(Queue queue) async {
    try {
      // Prefer customer_name stored on the queue (manual bookings) then fallback to users collection
      String customerName = 'Pelanggan Tidak Dikenal';
      try {
        final dataSnap = await FirebaseFirestore.instance
            .collection('queues')
            .doc(queue.id)
            .get();
        final qData = dataSnap.data();
        if (qData != null &&
            qData['customer_name'] != null &&
            (qData['customer_name'] as String).isNotEmpty) {
          customerName = qData['customer_name'] as String;
        } else {
          final userSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(queue.customerId)
              .get();
          customerName = userSnap.data()?['name'] ?? 'Pelanggan Tidak Dikenal';
        }
      } catch (_) {
        // best effort fallback to users collection
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(queue.customerId)
            .get();
        customerName = userSnap.data()?['name'] ?? 'Pelanggan Tidak Dikenal';
      }

      // Try to resolve service name from services collection, fallback to placeholder
      String serviceName = 'Signature Haircut';
      try {
        final svcId = queue.firstServiceId;
        if (svcId != null && svcId.isNotEmpty) {
          final svcSnap = await FirebaseFirestore.instance
              .collection('services')
              .doc(svcId)
              .get();
          if (svcSnap.exists) {
            final sdata = svcSnap.data();
            serviceName =
                (sdata?['name'] ?? sdata?['serviceName'] ?? serviceName)
                    .toString();
          }
        }
      } catch (_) {
        // keep fallback
      }

      return '$customerName|$serviceName';
    } catch (e) {
      debugPrint("Error fetching upcoming details: $e");
      return 'Pelanggan Loading...|Layanan Loading...';
    }
  }

  Color _getStatusColor(QueueStatus status) {
    switch (status) {
      case QueueStatus.waiting:
        return Colors.orangeAccent;
      case QueueStatus.booked:
        return const Color(0xFF448AFF);
      case QueueStatus.ongoing:
        return const Color(0xFF4CAF50);
      case QueueStatus.served:
        return Colors.grey;
      case QueueStatus.cancelled:
        return const Color(0xFFD32F2F);
      case QueueStatus.cancellationRequested:
        return Colors.orange;
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
        backgroundColor: kBrownAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingError.isNotEmpty) {
      return Scaffold(
        backgroundColor: kBlack,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              _loadingError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
          ),
        ),
      );
    }

    if (_adminBarbershopId == null) {
      return const Scaffold(
        backgroundColor: kBlack,
        body: Center(child: CircularProgressIndicator(color: kBrownAccent)),
      );
    }

    // Limit stream size to reduce UI load; counts should be fetched via helpers for accurate badges.
    final stream = _queueService.streamQueuesForBarbershop(
      _adminBarbershopId!,
      statusFilter: [
        QueueStatus.waiting.value,
        QueueStatus.booked.value,
        QueueStatus.ongoing.value,
        QueueStatus.served.value,
        QueueStatus.cancelled.value,
      ],
    );

    return Scaffold(
      backgroundColor: kBlack,
      floatingActionButton: FloatingActionButton(
        onPressed: _isRefreshing ? null : _manualRefresh,
        backgroundColor: kBrownAccent,
        tooltip: 'Segarkan',
        child: _isRefreshing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.refresh, color: Colors.black),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Queue>>(
          stream: stream,
          initialData: const <Queue>[],
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'Error Stream Data: ${snapshot.error}\n(Periksa Firestore index & rules)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }

            final allQueues = snapshot.data ?? [];

            // compute today's stats directly from stream data so UI always up-to-date
            final todayQueues = allQueues.where((q) {
              final today = DateTime.now();
              final bookingDate = q.bookingTime.toDate();
              return bookingDate.year == today.year &&
                  bookingDate.month == today.month &&
                  bookingDate.day == today.day;
            }).toList();

            // waiting = jumlah 'waiting'
            final pending = todayQueues
                .where((q) => q.status == QueueStatus.waiting)
                .length;
            // bookedCount = jumlah 'booked' (setelah verifikasi pembayaran oleh admin)
            final bookedCount = todayQueues
                .where((q) => q.status == QueueStatus.booked)
                .length;
            // ongoingCount = jumlah 'ongoing' (sudah mulai)
            final ongoingCount = todayQueues
                .where((q) => q.status == QueueStatus.ongoing)
                .length;
            // served = jumlah 'served' (selesai)
            final served = todayQueues
                .where((q) => q.status == QueueStatus.served)
                .length;

            // IMPORTANT: todayBookingCount should NOT include waiting.
            // Booking = confirmed bookings + ongoing (they are part of booking flow)
            final todayBookingCount = bookedCount + ongoingCount;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(
                    context,
                    todayBookingCount: todayBookingCount,
                    pendingCount: pending,
                    completedCount: served,
                  ),
                  _buildGridMenu(),
                  _buildUpcomingAppointment(allQueues),
                  const SizedBox(height: 50),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
