// lib/screens/customer/tabs/my_bookings_screen.dart (UPDATED FOR QueueStatus enum)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import Model yang Dibutuhkan
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/models/booking_details.dart'; // Asumsi model ini ada
import 'package:geges_smartbarber/services/queue_service.dart'; // Harus sudah di-update

// --- THEME COLORS (Konsisten) ---
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Mengambil data Queue dan mengubahnya menjadi BookingDetails
  /// dengan mengambil info dari koleksi lain (barbershops, barbermen, services).
  Future<BookingDetails> _fetchDetailsForQueue(Queue queue) async {
    const String defaultImage =
        'https://cdn-icons-png.flaticon.com/512/706/706830.png';

    try {
      String barbershopName = 'Barbershop Dihapus';
      String barbershopImage = defaultImage;
      String barbermanName = 'Barberman Dihapus';
      String serviceName = 'Layanan Dihapus';

      // 1. Fetch Barbershop
      final bsDoc = await FirebaseFirestore.instance
          .collection('barbershops')
          .doc(queue.barbershopId)
          .get();
      if (bsDoc.exists) {
        barbershopName = bsDoc.data()?['name'] ?? barbershopName;
        barbershopImage = bsDoc.data()?['imageUrl'] ?? defaultImage;
      }

      // 2. Fetch Barberman
      final bmDoc = await FirebaseFirestore.instance
          .collection('barbermen')
          .doc(queue.barbermanId)
          .get();
      if (bmDoc.exists) {
        barbermanName = bmDoc.data()?['name'] ?? barbermanName;
      }

      // 3. Fetch Service
      final serviceId = queue.firstServiceId;
      if (serviceId != null) {
        final svDoc = await FirebaseFirestore.instance
            .collection('services')
            .doc(serviceId)
            .get();
        if (svDoc.exists) {
          serviceName = svDoc.data()?['name'] ?? serviceName;

          if (queue.serviceIds != null && queue.serviceIds!.length > 1) {
            serviceName += ' (+${queue.serviceIds!.length - 1} lainnya)';
          }
        }
      }

      return BookingDetails(
        queue: queue,
        barbershopName: barbershopName,
        barbermanName: barbermanName,
        serviceName: serviceName,
        barbershopImage: barbershopImage,
      );
    } catch (e) {
      debugPrint("Error fetching details for queue ${queue.id}: $e");
      return BookingDetails(
        queue: queue,
        barbershopName: 'Gagal Memuat',
        barbermanName: 'Error',
        serviceName: 'Error',
        barbershopImage: defaultImage,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Bookings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingList(isCompleted: false), // Active
          _buildBookingList(isCompleted: true), // History
        ],
      ),
    );
  }

  Widget _buildBookingList({required bool isCompleted}) {
    if (_customerId == null) {
      return const Center(
        child: Text(
          'Anda harus login untuk melihat booking.',
          style: TextStyle(color: kTextGrey, fontSize: 16),
        ),
      );
    }

    // --- LOGIC FILTER PINDAH KE BACKEND (menggunakan statusFilter) ---
    final List<String> requiredStatus = isCompleted
        ? ['served', 'cancelled'] // History
        : ['waiting', 'booked', 'ongoing']; // Active (waiting + confirmed booked + ongoing)

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
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                // Pesan error diubah untuk mengingatkan indeks yang dibutuhkan
                'Gagal memuat data. Error: ${snapshot.error}. PASTIKAN INDEKS KOMPOSIT (customer_id, status, booking_time) SUDAH DIBUAT.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
            ),
          );
        }

        final filteredList = snapshot.data ?? [];

        if (filteredList.isEmpty) {
          return _buildEmptyState(isCompleted);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: filteredList.length,
          itemBuilder: (context, index) {
            final queue = filteredList[index];
            return _buildBookingCard(context, queue);
          },
        );
      },
    );
  }

  // Helper untuk state kosong
  Widget _buildEmptyState(bool isCompleted) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCompleted ? Icons.history : Icons.calendar_month,
            color: kTextGrey,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            isCompleted ? 'Tidak ada riwayat booking.' : 'Anda tidak memiliki booking aktif.',
            style: const TextStyle(color: kTextGrey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // --- WIDGET CARD ---
  Widget _buildBookingCard(BuildContext context, Queue queue) {
    return FutureBuilder<BookingDetails>(
      future: _fetchDetailsForQueue(queue),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          // Log error secara detail di console
          debugPrint('Error loading detail for queue ${queue.id}: ${snapshot.error}');
          return _buildErrorCard(queue.id, snapshot.error);
        }

        final details = snapshot.data!;
        final QueueStatus status = details.queue.status;

        final displayStatus = status.value.toUpperCase();

        final isServed = status == QueueStatus.served;
        final isPendingOrWaiting = status == QueueStatus.waiting || status == QueueStatus.booked;

        Color getStatusColor() {
          switch (status) {
            case QueueStatus.waiting:
              return Colors.grey.shade600;
            case QueueStatus.booked:
              return Colors.orangeAccent;
            case QueueStatus.ongoing:
              return Colors.blueAccent;
            case QueueStatus.served:
              return Colors.green;
            case QueueStatus.cancelled:
              return Colors.redAccent;
          }
        }

        String formatTimestamp(Timestamp t) {
          return DateFormat('EEE, d MMM yyyy, HH:mm').format(t.toDate());
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: kDarkGrey,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: getStatusColor().withValues(alpha: 0.5), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Barbershop & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: details.barbershopImage,
                            height: 35,
                            width: 35,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => const Icon(Icons.store, size: 35, color: kTextGrey),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            details.barbershopName,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: getStatusColor(),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      displayStatus,
                      style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 25),

              // Detail Booking
              _buildDetailRow('Layanan', details.serviceName),
              _buildDetailRow('Barberman', details.barbermanName),
              _buildDetailRow('Waktu Booking', formatTimestamp(details.queue.bookingTime)),

              if (details.queue.totalPrice != null)
                _buildDetailRow(
                  'Total Biaya',
                  NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                      .format(details.queue.totalPrice),
                  isAccent: true,
                ),

              // Tombol Aksi
              if (isPendingOrWaiting)
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          // TODO: Implement Cancel Logic using QueueService.updateQueueStatus / cancelQueue
                          _showSnackbar(context, 'Membatalkan order...', Colors.redAccent);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Navigate to Detail Screen (for confirmation/payment proof)
                          _showSnackbar(context, 'Melihat detail order...', kBrownAccent);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrownAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('View Details'),
                      ),
                    ],
                  ),
                )
              else if (isServed)
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          // TODO: Implement Give Rating Logic
                          _showSnackbar(context, 'Membuka form rating...', Colors.yellow);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber,
                          side: const BorderSide(color: Colors.amber),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Give Rating'),
                      ),
                    ],
                  ),
                )
            ],
          ),
        );
      },
    );
  }

  // --- Helper Widgets (Disederhanakan) ---

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      height: 220,
      decoration: BoxDecoration(
        color: kDarkGrey,
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: kBrownAccent),
      ),
    );
  }

  Widget _buildErrorCard(String queueId, Object? error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kDarkGrey,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Color.fromRGBO(255, 0, 0, 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gagal memuat detail: $queueId', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('Error: ${error?.toString().split(':').last.trim() ?? "Unknown error"}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAccent = false}) {
    // Sama seperti sebelumnya...
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: kTextGrey, fontSize: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: isAccent ? kBrownAccent : Colors.white,
                fontSize: 14,
                fontWeight: isAccent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 1)),
    );
  }
}
