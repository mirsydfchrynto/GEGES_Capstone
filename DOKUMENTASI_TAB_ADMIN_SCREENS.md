# DOKUMENTASI CUSTOMER TAB SCREENS & ADMIN SCREENS

## Pengantar
Tab screens adalah halaman-halaman yang diakses dari BottomNavigationBar di HomeScreen (4 tabs). Admin screens adalah dashboard khusus untuk owner/manager barbershop.

---

## Tab Screens (HomeScreen Navigation)

### Deskripsi Umum
HomeScreen punya 4 tabs:
1. **Home Tab** - Barbershop list dengan promo carousel (sudah di-dokumentasi)
2. **StyleScan Tab** - Scan hairstyle dengan AI
3. **Chatbot Tab** - Chat assistant
4. **Profile Tab** - User profile & settings

---

## 1. barbershop_detail_screen.dart

### Deskripsi
BarbershopDetailScreen menampilkan detail lengkap 1 barbershop dengan 3 sub-tabs:
- **About Tab** - Informasi umum (jam operasi, alamat, rating)
- **Services Tab** - Daftar layanan & harga
- **Review Tab** - Ulasan customer

### Features
- TabBar dengan 3 tab
- Dynamic review count (fetch dari firestore)
- Favorite status (check & toggle)
- Book appointment button
- Review rating display

### Struktur Code

```dart
// =====================================================
// INPUT: BARBERSHOP (dari previous screen)
// =====================================================
class BarbershopDetailScreen extends StatefulWidget {
  final Barbershop barbershop;

  const BarbershopDetailScreen({
    super.key,
    required this.barbershop,
  });

  @override
  State<BarbershopDetailScreen> createState() => _BarbershopDetailScreenState();
}

// =====================================================
// STATE WITH SINGLE TICKER (untuk tab animation)
// =====================================================
class _BarbershopDetailScreenState extends State<BarbershopDetailScreen>
    with SingleTickerProviderStateMixin {
  // penjelasan:
  // - mixin SingleTickerProviderStateMixin untuk provide ticker
  // - ticker digunakan oleh TabController untuk animate tab switching

  late TabController _tabController;

  // =====================================================
  // FIRESTORE & AUTH
  // =====================================================
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  // =====================================================
  // DYNAMIC DATA (di-fetch dari firestore)
  // =====================================================
  int _reviewCount = 0;              // jumlah review
  bool _isLoadingReviews = true;     // loading state
  
  bool _isFavorite = false;          // apakah barbershop ini favorite user
  bool _isLoadingFavorite = true;    // loading state

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchReviewCount();       // fetch jumlah review
    _checkIfFavorite();        // check apakah favorite
  }

  @override
  void dispose() {
    _tabController.dispose();  // cleanup tab controller
    super.dispose();
  }
```

### Key Method: _fetchReviewCount()

```dart
Future<void> _fetchReviewCount() async {
  // penjelasan:
  // - fetch jumlah review dari firestore
  // - gunakan .count() agar lebih efisien (tidak download semua dokumen)

  try {
    final snapshot = await _firestore
        .collection('reviews')
        .where('barbershopId', isEqualTo: widget.barbershop.id)
        .count()
        .get();

    if (mounted) {
      setState(() {
        _reviewCount = snapshot.count!;
        _isLoadingReviews = false;
      });
    }
  } catch (e) {
    debugPrint("error fetching review count: $e");
    if (mounted) {
      setState(() {
        _isLoadingReviews = false;
        _reviewCount = 0;  // default jika error
      });
    }
  }
}
```

### Key Method: _checkIfFavorite()

```dart
Future<void> _checkIfFavorite() async {
  // penjelasan:
  // - check apakah barbershop ini di-favorite oleh current user
  // - asumsi favorite disimpan di array 'favoriteBarbershops' di user doc

  if (_userId == null) {
    if (mounted) setState(() => _isLoadingFavorite = false);
    return;
  }

  try {
    final userDoc = await _firestore.collection('users').doc(_userId).get();
    if (userDoc.exists) {
      // ambil favorite array dari user doc
      final favorites = List<String>.from(
        userDoc.data()?['favoriteBarbershops'] ?? [],
      );

      if (mounted) {
        setState(() {
          _isFavorite = favorites.contains(widget.barbershop.id);
          _isLoadingFavorite = false;
        });
      }
    }
  } catch (e) {
    debugPrint("error checking favorite: $e");
    if (mounted) {
      setState(() => _isLoadingFavorite = false);
    }
  }
}
```

### Key Method: _toggleFavorite()

```dart
Future<void> _toggleFavorite() async {
  // penjelasan:
  // - toggle favorite status (add or remove dari favorite list)
  // - update firestore & local state

  if (_userId == null) return;

  try {
    final userRef = _firestore.collection('users').doc(_userId);
    final userDoc = await userRef.get();

    final favorites = List<String>.from(
      userDoc.data()?['favoriteBarbershops'] ?? [],
    );

    if (_isFavorite) {
      // jika sudah favorite, remove
      favorites.remove(widget.barbershop.id);
    } else {
      // jika belum favorite, add
      favorites.add(widget.barbershop.id);
    }

    // update firestore
    await userRef.update({'favoriteBarbershops': favorites});

    // update local state
    if (mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
      });
    }
  } catch (e) {
    debugPrint("error toggling favorite: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error: $e')),
      );
    }
  }
}
```

### UI: Build TabBar

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      title: Text(widget.barbershop.name),
      actions: [
        // favorite button
        IconButton(
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isLoadingFavorite ? Colors.grey : kBrownAccent,
          ),
          onPressed: _isLoadingFavorite ? null : _toggleFavorite,
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: kBrownAccent,
        labelColor: kBrownAccent,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: 'about'),
          Tab(text: 'services'),
          Tab(text: 'reviews'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [
        AboutTab(barbershop: widget.barbershop),
        ServicesTab(shop: widget.barbershop),
        ReviewTab(barbershopId: widget.barbershop.id),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AppointmentScreen(
              barbershop: widget.barbershop,
            ),
          ),
        );
      },
      label: const Text('book appointment'),
      icon: const Icon(Icons.calendar_today),
      backgroundColor: kBrownAccent,
    ),
  );
}
```

---

## 2. services_tab.dart & other Tab Screens

### Deskripsi
Tab screens menampilkan informasi spesifik:
- **ServicesTab** - Daftar service & harga
- **AboutTab** - Informasi barbershop (jam, alamat, rating)
- **ReviewTab** - Ulasan customer
- **ProfileScreen** - User profile & history
- **ChatAssistantScreen** - AI chatbot
- **StyleScanScreen** - Hairstyle recommendation
- **FavoriteBarbershopsScreen** - Favorite barbershops list

### Contoh: ServicesTab

```dart
class ServicesTab extends StatelessWidget {
  final Barbershop shop;
  // penjelasan:
  // - stateless widget karena hanya display data
  // - tidak ada state yang berubah

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  // penjelasan:
  // - format currency untuk display harga
  // - 'id_ID' = Indonesian locale
  // - Rp = simbol rupiah

  const ServicesTab({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    // asumsi: shop.services adalah List<Service>
    // jika masih List<String> (service ids), perlu fetch service details dulu

    final services = shop.services; // atau fetch dari service

    return ListView.separated(
      padding: const EdgeInsets.all(24.0),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kDarkGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${service.defaultDuration} min',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                _currencyFormat.format(service.price),
                style: const TextStyle(
                  color: kBrownAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 16),
    );
  }
}
```

---

## Admin Screens

### Deskripsi
Admin screens adalah dashboard untuk owner/manager barbershop untuk manage bookings dan queue.

---

## 1. admin_dashboard.dart

### Deskripsi
AdminDashboard adalah main screen untuk admin dengan:
- Barbershop status (open/close toggle)
- Stats display (total booking, customer, revenue)
- Barbershop info display
- Navigasi ke live queue & manual booking

### Features
- Status toggle (open/closed)
- Real-time stats dari firestore
- Quick navigation buttons
- Barbershop info display
- Logout button

### Struktur Code

```dart
// =====================================================
// CONSTANTS
// =====================================================
const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkSurface = Color(0xFF1E1E1E);
const Color kBlack = Colors.black;

// =====================================================
// MAIN WIDGET
// =====================================================
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

// =====================================================
// STATE CLASS
// =====================================================
class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // =====================================================
  // SERVICES
  // =====================================================
  final QueueService _queueService = QueueService();
  final BarbershopService _barbershopService = BarbershopService();
  final AuthService _auth_service = AuthService();

  // =====================================================
  // STATE DATA
  // =====================================================
  final String? _adminUid = FirebaseAuth.instance.currentUser?.uid;
  UserData? _currentAdminData;
  String? _adminBarbershopId;
  String _barbershopName = "Loading...";
  String _loadingError = '';

  // =====================================================
  // BARBERSHOP STATUS
  // =====================================================
  bool _isShopOpen = false;           // barbershop open/close status
  bool _isTogglingStatus = false;     // prevent double toggle

  @override
  void initState() {
    super.initState();
    _loadAdminData();  // load admin data saat screen pertama kali mount
  }

  // =====================================================
  // KEY METHOD: Load Admin Data
  // =====================================================
  Future<void> _loadAdminData() async {
    // penjelasan:
    // - check admin uid
    // - fetch admin user data
    // - validate admin role
    // - fetch barbershop info
    // - fetch barbershop status (open/closed)

    if (_adminUid == null) {
      _logout(context);
      return;
    }

    try {
      // step 1: fetch admin user data
      final adminData = await _auth_service.getUserById(_adminUid!);

      if (adminData == null) {
        // admin data not found
        if (mounted) {
          setState(() {
            _loadingError =
                'ERROR: admin id ($_adminUid) tidak ditemukan di users collection.';
          });
        }
        return;
      }

      // step 2: validate admin role
      if (adminData.role != 'admin_owner' && adminData.role != 'owner') {
        if (mounted) {
          setState(() {
            _loadingError = 'ERROR: akses ditolak. role anda: ${adminData.role}.';
          });
        }
        return;
      }

      // step 3: check barbershop id
      final barbershopId = adminData.barbershopId;
      if (barbershopId == null || barbershopId.isEmpty) {
        if (mounted) {
          setState(() {
            _loadingError =
                'ERROR: admin ${adminData.name} tidak terikat pada barbershop apapun.';
          });
        }
        return;
      }

      // step 4: fetch barbershop data
      final barbershop = await _barbershopService.getBarbershopById(barbershopId);

      if (mounted) {
        setState(() {
          _currentAdminData = adminData;
          _adminBarbershopId = barbershopId;
          _barbershopName = barbershop?.name ?? 'unknown';
          _isShopOpen = barbershop?.isOpen ?? false;
        });
      }
    } catch (e) {
      debugPrint("error loading admin data: $e");
      if (mounted) {
        setState(() {
          _loadingError = 'error: $e';
        });
      }
    }
  }

  // =====================================================
  // KEY METHOD: Toggle Shop Status
  // =====================================================
  Future<void> _toggleShopStatus() async {
    // penjelasan:
    // - toggle barbershop status (open ↔ closed)
    // - update firestore
    // - prevent double toggle dengan _isTogglingStatus flag

    if (_adminBarbershopId == null || _isTogglingStatus) return;

    setState(() => _isTogglingStatus = true);

    try {
      // update firestore
      await FirebaseFirestore.instance
          .collection('barbershops')
          .doc(_adminBarbershopId)
          .update({'isOpen': !_isShopOpen});

      // update local state
      if (mounted) {
        setState(() {
          _isShopOpen = !_isShopOpen;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isShopOpen ? 'barbershop dibuka' : 'barbershop ditutup',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("error toggling shop status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingStatus = false);
      }
    }
  }

  // =====================================================
  // KEY METHOD: Logout
  // =====================================================
  void _logout(BuildContext context) async {
    // penjelasan:
    // - logout from firebase
    // - navigate ke login screen
    // - clear semua routes (pushAndRemoveUntil)

    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,  // remove semua route sebelumnya
      );
    }
  }
```

### UI: Build Method

```dart
@override
Widget build(BuildContext context) {
  // jika ada error saat load data, tampilkan error message
  if (_loadingError.isNotEmpty) {
    return Scaffold(
      backgroundColor: kBlack,
      appBar: AppBar(
        backgroundColor: kBlack,
        title: const Text('admin dashboard'),
      ),
      body: Center(
        child: Text(
          _loadingError,
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  return Scaffold(
    backgroundColor: kBlack,
    appBar: AppBar(
      backgroundColor: kBlack,
      title: const Text('admin dashboard'),
      actions: [
        // logout button
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _logout(context),
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =====================================================
          // BARBERSHOP INFO CARD
          // =====================================================
          Card(
            color: kDarkSurface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _barbershopName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'status: ${_isShopOpen ? 'open' : 'closed'}',
                        style: TextStyle(
                          color: _isShopOpen ? Colors.green : Colors.red,
                          fontSize: 16,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isTogglingStatus ? null : _toggleShopStatus,
                        label: Text(_isShopOpen ? 'close' : 'open'),
                        icon: Icon(
                          _isShopOpen ? Icons.lock : Icons.lock_open,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // =====================================================
          // QUICK ACTION BUTTONS
          // =====================================================
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildQuickActionButton(
                icon: Icons.queue,
                label: 'live queue',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LiveQueueScreen(),
                    ),
                  );
                },
              ),
              _buildQuickActionButton(
                icon: Icons.add_circle,
                label: 'add manual booking',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AddManualBookingScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildQuickActionButton({
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
}) {
  return Card(
    color: kDarkSurface,
    child: InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: kBrownAccent),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
```

---

## 2. live_queue_screen.dart

### Deskripsi
LiveQueueScreen menampilkan real-time queue untuk barbershop admin. Lihat booking aktif (booked/ongoing), dan manage queue (start service, finish service, cancel booking).

### Features
- Real-time queue list (stream dari firestore)
- Status filters (booked, ongoing, all)
- Action buttons (start, finish, cancel)
- Queue card dengan detail booking
- Barberman & service info

---

## Summary

### Tab Navigation Structure
```
HomeScreen (StatefulWidget dengan PageView)
    ├─ Home Tab
    │   └─ Promo carousel + barbershop list
    │       └─ BarbershopDetailScreen
    │           ├─ AboutTab
    │           ├─ ServicesTab
    │           └─ ReviewTab
    │               └─ AppointmentScreen
    │
    ├─ StyleScan Tab
    │   └─ StyleScanScreen (AI hairstyle recommendation)
    │
    ├─ Chatbot Tab
    │   └─ ChatAssistantScreen (AI chatbot)
    │
    └─ Profile Tab
        └─ ProfileScreen (user profile & menu)
            ├─ Edit Profile button → EditProfileScreen
            ├─ My Bookings button → MyBookingsScreen
            ├─ Favorites button → FavoriteBarbershopsScreen
            └─ Logout button → LoginScreen
```

### Admin Navigation Structure
```
LoginScreen (admin account)
    ↓
AdminDashboardScreen
    ├─ Open/Close toggle
    ├─ Live Queue button → LiveQueueScreen
    │   ├─ View booking list (real-time)
    │   └─ Actions (start, finish, cancel)
    │
    └─ Add Manual Booking button → AddManualBookingScreen
        ├─ Select customer
        ├─ Select barberman
        ├─ Select service
        └─ Create booking
```

### Best Practices
1. **Use TabController dengan SingleTickerProviderStateMixin** untuk tab navigation
2. **Fetch dynamic data dengan FutureBuilder/StreamBuilder** untuk real-time updates
3. **Toggle buttons harus prevent double-tap** dengan loading flag
4. **Always dispose TabController** di dispose method
5. **Check mounted before setState** setelah async operations
6. **Use specific error messages** untuk debugging

