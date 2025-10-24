import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import file-file yang sudah kita buat
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/screens/login_screen.dart';
// Import halaman CV (yang akan dibuat Tim 4)
// import 'package:geges_smartbarber/screens/customer/cv_consultation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Service untuk mengambil data
  final BarbershopService _barbershopService = BarbershopService();
  int _selectedIndex = 0; // Untuk Bottom Navigation Bar

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
      // 1. Bottom Navigation Bar (Sesuai Desain 52027.jpg)
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Booking'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
        ],
        type: BottomNavigationBarType.fixed, // Penting agar 4 icon terlihat
        backgroundColor: Colors.black,
        selectedItemColor: Colors.deepPurple, // Warna aktif
        unselectedItemColor: Colors.white54, // Warna non-aktif
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // TODO: Tambahkan navigasi ke halaman Booking, Chat, Setting
          });
        },
      ),

      // Body menggunakan CustomScrollView (Slivers) agar fleksibel
      body: CustomScrollView(
        slivers: [
          // 2. Header (Selamat Datang M. Irsyad Fachryanto)
          SliverAppBar(
            title: const Text('Selamat Datang M. Irsyad'),
            floating: true, // App bar muncul saat scroll ke atas
            pinned: false,
            backgroundColor: Colors.black,
            actions: [
              // Tombol Akun & Logout
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  onPressed: () => _logout(context),
                  tooltip: 'Logout',
                ),
              ),
            ],
          ),

          // 3. Search Bar (Sesuai Desain 52027.jpg)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari barbershop, layanan...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: const Icon(Icons.tune), // Ikon filter
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          
          // 4. Placeholder Iklan Produk (Pomade, sesuai Desain 52027.jpg)
          SliverToBoxAdapter(
            child: Container(
              height: 180,
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade900, // Warna gelap placeholder
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Text(
                  "Promo Pomade Terbaik (Sesuai Desain)", 
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ),
          ),
          
          // 5. Grid Kategori (Haircut, Trim & Shave, dll.)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverGrid.count(
              crossAxisCount: 4,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                // Ini adalah implementasi dari desain Anda
                _buildCategoryIcon(Icons.content_cut, 'Haircut', onTap: () {}),
                _buildCategoryIcon(Icons.brush, 'Trim & Shave', onTap: () {}),
                _buildCategoryIcon(Icons.wash, 'Hairwash', onTap: () {}),
                _buildCategoryIcon(Icons.color_lens, 'Coloring', onTap: () {}),
                _buildCategoryIcon(Icons.shopping_bag, 'Products', onTap: () {}),
                _buildCategoryIcon(Icons.face_retouching_natural, 'Hairmask', onTap: () {}),
                
                // Kriteria Wajib Dosen: CV (Analisis Citra)
                _buildCategoryIcon(Icons.camera_alt, 'Cek Wajah', onTap: () {
                  // TODO: Navigasi ke CVConsultationScreen (Tugas Tim 4)
                  // Navigator.push(context, MaterialPageRoute(builder: (context) => const CVConsultationScreen()));
                }),

                // Kriteria Wajib Dosen: NLP (Chatbot)
                _buildCategoryIcon(Icons.chat_bubble, 'Chatbot', onTap: () {
                  // TODO: Navigasi ke ChatbotScreen (Tugas Tim 3)
                }),
              ],
            ),
          ),
          
          // 6. Judul "Rekomendasi"
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
              child: Text(
                "Rekomendasi", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
              ),
            ),
          ),

          // 7. List Barbershop (DATA LIVE DARI FIREBASE!)
          // Kita gunakan FutureBuilder untuk mengambil data secara asynchronous
          FutureBuilder<List<Barbershop>>(
            future: _barbershopService.getAllBarbershops(),
            builder: (context, snapshot) {
              // Saat data sedang dimuat
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              // Jika ada error
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(child: Text("Gagal memuat barbershop atau data kosong.")),
                );
              }
              
              // Jika data berhasil diambil
              final barbershops = snapshot.data!;
              
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: 230, // Ketinggian untuk list horizontal
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: barbershops.length,
                    itemBuilder: (context, index) {
                      final shop = barbershops[index];
                      // Panggil widget card untuk setiap barbershop
                      return _buildBarbershopCard(context, shop);
                    },
                  ),
                ),
              );
            },
          ),
          
          // Spacer di bagian bawah
          const SliverToBoxAdapter(
            child: SizedBox(height: 30),
          )
        ],
      ),
    );
  }

  // Widget Pembantu untuk Ikon Kategori
  Widget _buildCategoryIcon(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white10,
            child: Icon(icon, size: 30, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }

  // Widget Pembantu untuk Card Barbershop (Sesuai Desain 52027.jpg)
  Widget _buildBarbershopCard(BuildContext context, Barbershop shop) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigasi ke AppointmentScreen (Tugas Tim 3)
        // Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentScreen(barbershop: shop)));
      },
      child: Container(
        width: 160,
        margin: EdgeInsets.only(left: 16, bottom: 10, top: 10), // Margin untuk shadow
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
             BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: Offset(4, 4),
            ),
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Barbershop (Ganti dengan NetworkImage nanti)
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade700,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                // Ganti dengan gambar barbershop
                // image: DecorationImage(image: NetworkImage(shop.imageUrl), fit: BoxFit.cover)
              ),
              child: Center(child: Text(shop.name[0], style: TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold))), // Placeholder
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(shop.rating.toString(), style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                   Text(
                    shop.address, 
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

