import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import service dan model yang kita butuhkan
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/screens/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final QueueService _queueService = QueueService();
  int _selectedIndex = 0; // Untuk navigasi (0: Antrean, 1: Barberman, 2: Layanan)

  // Fungsi Logout
  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard (Web) - GEGES'),
        backgroundColor: Colors.blueGrey[900], // Warna beda untuk admin
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Row(
        children: [
          // 1. Navigasi Samping (Cocok untuk Web)
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.grey.shade900,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.timer),
                selectedIcon: Icon(Icons.timer, color: Colors.deepPurple),
                label: Text('Antrean Live'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                selectedIcon: Icon(Icons.people, color: Colors.deepPurple),
                label: Text('Kelola Barberman'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.content_cut),
                selectedIcon: Icon(Icons.content_cut, color: Colors.deepPurple),
                label: Text('Kelola Layanan'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),

          // 2. Konten Halaman (Berubah sesuai navigasi)
          Expanded(
            child: _buildSelectedScreen(_selectedIndex),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk menampilkan halaman yang dipilih
  Widget _buildSelectedScreen(int index) {
    switch (index) {
      case 0:
        return _buildQueueManagementScreen(); // Fokus utama AI
      case 1:
        return _buildCrudScreen("Kelola Barberman"); // TODO: Dibuat Tim 2
      case 2:
        return _buildCrudScreen("Kelola Layanan"); // TODO: Dibuat Tim 2
      default:
        return _buildQueueManagementScreen();
    }
  }

  // Halaman 1: Manajemen Antrean (INPUT DATA AI)
  Widget _buildQueueManagementScreen() {
    // ID Barbershop harus didapat dari data Admin yang login
    // Kita hardcode dulu untuk tes, ganti dengan ID Febrian Barbershop dari Firebase Anda
    const String barbershopId = "febrian_barber"; 
    
    return StreamBuilder<List<Queue>>(
      // Menggunakan StreamBuilder untuk data Real-time
      stream: _queueService.getActiveQueueStream(barbershopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              "Tidak ada antrean saat ini.",
              style: TextStyle(fontSize: 24, color: Colors.white54),
            ),
          );
        }

        // Tampilkan daftar antrean
        final queues = snapshot.data!;
        return ListView.builder(
          itemCount: queues.length,
          itemBuilder: (context, index) {
            final queue = queues[index];
            
            // Tentukan status untuk tombol
            bool isOngoing = queue.status == 'ongoing';
            bool isPending = queue.status == 'pending';

            return Card(
              margin: const EdgeInsets.all(12.0),
              color: Colors.grey.shade800,
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                // TODO: Ganti ID dengan nama customer/barberman (perlu query tambahan)
                title: Text("Customer: ${queue.customerId}"),
                subtitle: Text("Barberman: ${queue.barbermanId}"),
                trailing: isPending
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () {
                          // Tekan "Mulai"
                          _queueService.startService(queue.id);
                        },
                        child: const Text("Mulai Potong"),
                      )
                    : (isOngoing && queue.startTime != null)
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () {
                              // Tekan "Selesai"
                              // Tampilkan dialog konfirmasi
                              _showFinishDialog(context, queue.id, queue.startTime!);
                            },
                            child: const Text("Selesai Potong"),
                          )
                        : const Chip(label: Text("Selesai"), backgroundColor: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  // Dialog Konfirmasi untuk Tombol Selesai
  void _showFinishDialog(BuildContext context, String queueId, Timestamp startTime) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Konfirmasi Selesai'),
          content: const Text('Apakah Anda yakin layanan ini sudah selesai?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                // Panggil service untuk menghitung durasi dan update status
                _queueService.finishService(queueId, startTime);
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Ya, Selesai'),
            ),
          ],
        );
      },
    );
  }


  // Halaman 2 & 3: Placeholder untuk CRUD
  Widget _buildCrudScreen(String title) {
    // TODO: Tim 2 akan membangun UI untuk CRUD Barberman dan Service di sini
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text("Tim 2: Implementasikan CRUD (Create, Read, Update, Delete) di sini."),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {},
            child: const Text("Contoh Tombol Tambah Data"),
          )
        ],
      ),
    );
  }
}

