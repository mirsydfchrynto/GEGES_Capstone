# DOKUMENTASI LENGKAP GEGES SMARTBARBER

## Daftar Isi
1. [Pengenalan Struktur Aplikasi](#pengenalan-struktur-aplikasi)
2. [Penjelasan Widgets yang Digunakan](#penjelasan-widgets)
3. [Penjelasan Models (Data)](#penjelasan-models)
4. [Penjelasan Services (Logika Backend)](#penjelasan-services)
5. [Penjelasan Screens (Halaman UI)](#penjelasan-screens)
6. [Styling dan Tema](#styling-dan-tema)
7. [Navigasi Antar Halaman](#navigasi-antar-halaman)

---

## PENGENALAN STRUKTUR APLIKASI

### Folder Structure
```
lib/
├── main.dart                          # entry point aplikasi (file pertama yang dijalankan)
├── firebase_options.dart              # konfigurasi firebase
├── models/                            # folder berisi model (blueprint data)
│   ├── barbershop.dart               # data barbershop
│   ├── queue.dart                    # data antrian/booking
│   ├── service.dart                  # data layanan potong/styling
│   ├── barberman.dart                # data barber
│   ├── user_data.dart                # data user customer
│   ├── booking_details.dart          # detail booking gabungan
│   └── promo_banner.dart             # data promo
├── services/                          # folder berisi service (logic & data fetching)
│   ├── auth_service.dart             # handle login/register
│   ├── barbershop_service.dart       # ambil data barbershop dari firebase
│   ├── queue_service.dart            # handle booking (create, update, delete)
│   ├── barberman_service.dart        # ambil data barber
│   └── service_service.dart          # ambil data layanan
├── screens/                           # folder berisi halaman UI
│   ├── login_screen.dart             # halaman login
│   ├── register_screen.dart          # halaman register
│   ├── onboarding_screen.dart        # halaman pengenalan app
│   ├── admin/                        # folder halaman admin
│   │   ├── add_manual_booking_screen.dart
│   │   ├── admin_dashboard.dart
│   │   ├── live_queue_screen.dart
│   │   └── booking_confirmation_screen.dart
│   └── customer/                     # folder halaman customer
│       ├── home_screen.dart          # halaman utama (dengan 4 tab)
│       ├── appointment_screen.dart   # halaman booking
│       ├── payment_screen.dart       # halaman pembayaran
│       ├── edit_profile_screen.dart  # halaman edit profil
│       └── tabs/                     # subfolder untuk 4 tab di home screen
│           ├── barbershop_detail_screen.dart  # detail barbershop
│           ├── profile_screen.dart            # tab profile
│           ├── chat_assistant_screen.dart     # tab chatbot
│           ├── stylescan_screen.dart          # tab style scan
│           ├── about_tab.dart                 # tab info di detail barbershop
│           ├── services_tab.dart              # tab layanan di detail barbershop
│           ├── review_tab.dart                # tab review di detail barbershop
│           ├── my_bookings_screen.dart        # my bookings screen
│           └── favorite_barbershops_screen.dart  # favorit barbershop
└── widgets/                          # folder berisi widget reusable
    ├── utility/
    │   └── loading_widget.dart       # widget loading spinner
    └── admin/
        └── queue_card.dart           # card untuk tampil antrian
```

### Alur Aplikasi
```
main.dart (MyApp - setup tema & firebase)
    ↓
onboarding_screen.dart (pengenalan app)
    ↓
login_screen.dart / register_screen.dart (autentikasi)
    ↓
home_screen.dart (halaman utama dengan 4 tab: home, stylescan, chatbot, profile)
    ├── Tab 1: Home
    │   ├── Header (greeting + notification)
    │   ├── Search bar (cari barbershop)
    │   ├── Promo carousel (slider banner promo)
    │   └── Barbershop list (daftar barbershop recommended)
    │
    ├── Tab 2: StyleScan
    │   └── Gunakan kamera + AI untuk scan gaya rambut
    │
    ├── Tab 3: Chatbot
    │   └── Chat dengan AI assistant
    │
    └── Tab 4: Profile
        └── Lihat & edit profil user

Flow Booking:
home_screen (tap barbershop card)
    ↓
barbershop_detail_screen (lihat detail, review, service)
    ↓
appointment_screen (pilih barber, service, waktu)
    ↓
payment_screen (bayar)
    ↓
booking confirmation (booking berhasil)
```

---

## PENJELASAN WIDGETS

### Widget adalah Component UI (Blok Bangunan)

Widget adalah class yang membuat tampilan di layar. Di Flutter, "everything is a widget".

**Jenis Widget:**

#### 1. Stateless Widget (Tidak Berubah)
```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // return UI yang tidak berubah
    return Text("Hello");
  }
}
```
- Tidak punya state (data yang berubah)
- Efficient, ringan
- Contoh: Text, Icon, Container, Image

#### 2. Stateful Widget (Bisa Berubah)
```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  int counter = 0;
  
  @override
  Widget build(BuildContext context) {
    return Text("$counter");
  }
}
```
- Punya state (data yang bisa berubah)
- setState() untuk notify flutter ada perubahan
- Contoh: HomeScreen, AppointmentScreen

### Widget Umum yang Digunakan

#### Scaffold
```dart
Scaffold(
  appBar: AppBar(...),          // header di atas
  body: Container(...),         // isi utama
  floatingActionButton: ...,    // tombol round di kanan bawah
  bottomNavigationBar: ...,     // navigation bar di bawah
)
```
- Layout dasar flutter
- Untuk membuat struktur halaman dengan app bar, body, navigation

#### AppBar
```dart
AppBar(
  title: Text("Judul"),
  backgroundColor: Colors.blue,
  elevation: 0,                 // tinggi bayangan
  leading: IconButton(...),     // icon di sebelah kiri
  actions: [...],               // icon di sebelah kanan
)
```
- Header di atas layar
- Biasanya untuk judul & aksi halaman

#### PageView
```dart
PageView(
  controller: pageController,
  onPageChanged: (index) {...},
  children: [
    Widget1(),    // halaman 1
    Widget2(),    // halaman 2
    Widget3(),    // halaman 3
  ]
)
```
- Untuk swipe antar halaman (seperti Instagram story)
- Digunakan di HomeScreen untuk swipe 4 tab
- controller: untuk kontrol programmatic
- onPageChanged: callback saat swipe

#### BottomNavigationBar
```dart
BottomNavigationBar(
  items: [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
  ],
  currentIndex: selectedIndex,
  onTap: (index) { ... },
)
```
- Navigation bar di bawah layar
- Untuk tab navigation (home, chat, profile, dll)
- currentIndex: tab mana yang highlight
- onTap: callback saat tab diklik

#### Container
```dart
Container(
  width: 100,
  height: 100,
  color: Colors.blue,
  padding: EdgeInsets.all(16),
  margin: EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: Colors.red,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: Colors.black),
    boxShadow: [...],
  ),
  child: Text("Hello"),
)
```
- Widget versatile untuk styling & layout
- width/height: ukuran
- padding: jarak child dari tepi container
- margin: jarak container dari widget lain
- decoration: styling (warna, border, shadow)

#### Row & Column
```dart
Row(                        // layout horizontal (kiri-kanan)
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [Widget1(), Widget2()],
)

Column(                     // layout vertikal (atas-bawah)
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [Widget1(), Widget2()],
)
```
- Row: layout horizontal
- Column: layout vertikal
- mainAxisAlignment: distribute widget dalam main axis
- crossAxisAlignment: align widget dalam cross axis
- children: list widget yang diatur

#### ListView
```dart
ListView(
  padding: EdgeInsets.all(16),
  children: [
    Widget1(),
    Widget2(),
    Widget3(),
  ]
)

// atau
ListView.builder(
  itemCount: 10,
  itemBuilder: (context, index) {
    return Widget();
  }
)
```
- Scrollable list widget
- children: list widget yang bisa scroll
- builder: efficient untuk list besar (lazy loading)

#### SingleChildScrollView
```dart
SingleChildScrollView(
  child: Container(
    child: Column(...),
  )
)
```
- Membuat child widget bisa scroll
- Contoh di login screen (form bisa scroll jika content panjang)

#### GestureDetector
```dart
GestureDetector(
  onTap: () { ... },        // callback saat user tap
  onLongPress: () { ... },  // callback saat long press
  onDoubleTap: () { ... },  // callback saat double tap
  child: Container(...),
)
```
- Membuat child widget responsive terhadap gesture (tap, drag, dll)
- onTap: callback saat tap
- Sering digunakan untuk membuat tombol custom

#### TextField (Input Box)
```dart
TextField(
  controller: textController,
  decoration: InputDecoration(
    hintText: "Masukkan nama",
    labelText: "Nama",
    prefixIcon: Icon(Icons.person),
    border: OutlineInputBorder(),
  ),
  keyboardType: TextInputType.email,
  onChanged: (value) { ... },
)
```
- Input box untuk user ketik text
- controller: untuk get/set value
- decoration: styling input box
- keyboardType: jenis keyboard (email, number, dll)
- onChanged: callback saat user ketik

#### ElevatedButton
```dart
ElevatedButton(
  onPressed: () { ... },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
    padding: EdgeInsets.all(16),
  ),
  child: Text("Click Me"),
)
```
- Tombol berisi (solid color)
- onPressed: callback saat diklik
- style: customize tampilan tombol
- child: text/icon yang ditampilkan

#### FutureBuilder
```dart
FutureBuilder<List<Barbershop>>(
  future: barbershopService.getAllBarbershops(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return LoadingWidget();  // sedang loading
    }
    if (snapshot.hasError) {
      return Text("Error: ${snapshot.error}");  // ada error
    }
    if (!snapshot.hasData) {
      return Text("No data");  // data kosong
    }
    
    final data = snapshot.data!;
    return ListView.builder(...);  // tampilkan data
  }
)
```
- Widget untuk handle async data (dari firebase, api, dll)
- future: async task yang sedang dijalankan
- builder: function yang return widget sesuai state (loading, error, done)
- snapshot.connectionState: state async task
- snapshot.data: data hasil async task
- Sangat penting untuk loading data dari firebase

#### StreamBuilder
```dart
StreamBuilder<List<Queue>>(
  stream: queueService.streamQueuesForCustomer(userId),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final queues = snapshot.data!;
      return ListView(...);
    }
    return LoadingWidget();
  }
)
```
- Widget untuk handle stream data (realtime updates dari firebase)
- stream: stream yang di-listen
- builder: function yang return widget saat ada data baru
- Berbeda dengan FutureBuilder (future = sekali, stream = realtime)

#### TabBar & TabBarView
```dart
DefaultTabController(
  length: 3,
  child: Scaffold(
    appBar: AppBar(
      bottom: TabBar(
        tabs: [
          Tab(text: "Tab 1"),
          Tab(text: "Tab 2"),
          Tab(text: "Tab 3"),
        ],
      ),
    ),
    body: TabBarView(
      children: [
        Widget1(),
        Widget2(),
        Widget3(),
      ],
    ),
  )
)
```
- Untuk tab navigation di atas halaman
- TabBar: tombol tab
- TabBarView: konten setiap tab
- Berbeda dengan BottomNavigationBar (ini di bawah)

#### CachedNetworkImage
```dart
CachedNetworkImage(
  imageUrl: "https://example.com/image.jpg",
  fit: BoxFit.cover,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```
- Widget untuk menampilkan image dari internet
- Download & cache otomatis
- placeholder: widget saat sedang download
- errorWidget: widget jika download gagal

#### SafeArea
```dart
SafeArea(
  child: Column(...)
)
```
- Membuat child widget aman dari notch/cutout (di tepi layar)
- Penting untuk tdk di-cover oleh status bar atau navigation bar

#### Expanded & Flexible
```dart
Row(
  children: [
    Container(width: 100),
    Expanded(
      child: Container(),  // ambil sisa space
    ),
  ]
)
```
- Expanded: child widget mengambil sisa space
- Flexible: sama tapi lebih flexible

#### SizedBox
```dart
SizedBox(
  width: 100,
  height: 100,
  child: Container(),
)
```
- Widget untuk set ukuran child
- Atau membuat spacing (SizedBox(height: 20))

### Widget Styling

#### Padding
```dart
Padding(
  padding: EdgeInsets.all(16),           // semua sisi 16
  // atau
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  // atau
  padding: EdgeInsets.only(left: 16, right: 16, top: 8),
  child: Text("Hello"),
)
```

#### Decoration (Border, Shadow, Gradient)
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: Colors.black, width: 2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 5,
        offset: Offset(0, 2),
      ),
    ],
    gradient: LinearGradient(
      colors: [Colors.blue, Colors.red],
    ),
  ),
)
```

#### Text Styling
```dart
Text(
  "Hello",
  style: TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,      // tebal
    fontStyle: FontStyle.italic,      // miring
    letterSpacing: 1,                  // jarak huruf
    decoration: TextDecoration.underline,  // garis bawah
  ),
)
```

---

## PENJELASAN MODELS (Data)

### Apa itu Model?

Model adalah blueprint atau template untuk struktur data. Model menggambarkan "apa saja properti yang dimiliki data ini".

Contoh: Model Barbershop memiliki properti: id, name, address, rating, imageUrl, dll.

### Model yang Ada di Aplikasi

#### 1. Barbershop Model
```dart
class Barbershop {
  final String id;              // id unik dari firebase
  final String name;            // nama barbershop (contoh: "Barber Premium")
  final String addres;          // alamat (typo di database)
  final double rating;          // rating 0.0 - 5.0
  final String imageUrl;        // url gambar
  final List<String> services;  // list id layanan yang ada
  final int openHour;           // jam buka (0-23)
  final int closeHour;          // jam tutup (0-23)
  final bool isOpen;            // status buka/tutup sekarang
}
```
- Merepresentasikan satu barbershop
- factory Barbershop.fromFirestore(): convert firebase data → object Barbershop
- toJson(): convert object → map (untuk simpan ke firebase)

#### 2. Queue Model
```dart
class Queue {
  final String id;                    // id unik booking
  final String barbershopId;          // id barbershop
  final String customerId;            // id customer yang booking
  final String barbermanId;           // id barber
  final Timestamp bookingTime;        // waktu booking dibuat
  final Timestamp? startTime;         // waktu barber mulai (nullable)
  final Timestamp? finishTime;        // waktu barber selesai
  final List<String>? serviceIds;     // list id service yang dipilih
  final int? totalPrice;              // harga total
  final QueueStatus status;           // waiting, booked, ongoing, served, cancelled
  final Timestamp? createdAt;         // waktu record dibuat
}

enum QueueStatus { waiting, booked, ongoing, served, cancelled }
```
- Merepresentasikan satu booking/antrian
- enum QueueStatus: status hanya bisa salah satu dari 5 pilihan
- Timestamp: tipe data firebase untuk waktu

#### 3. Barberman Model
```dart
class Barberman {
  final String id;              // id barber
  final String name;            // nama barber
  final String barbershopId;    // id barbershop tempat kerja
  final double rating;          // rating barber
  final double avgDuration;     // rata-rata durasi potong (menit)
  final bool isActive;          // apakah barber aktif/tersedia
}
```
- Merepresentasikan satu barber
- rating: penilaian dari customer
- avgDuration: estimasi waktu potong

#### 4. Service Model
```dart
class Service {
  final String id;                // id service
  final String name;              // nama layanan (contoh: "Potong Rambut")
  final String description;       // deskripsi detail
  final double price;             // harga
  final int defaultDuration;      // durasi default (menit)
  final bool isActive;            // apakah service aktif
}
```
- Merepresentasikan satu jenis layanan potong
- price: harga service
- defaultDuration: estimasi waktu pengerjaan

#### 5. UserData Model
```dart
class UserData {
  final String id;              // id user (sama dengan firebase auth uid)
  final String name;            // nama user
  final String email;           // email user
  final String? phoneNumber;    // nomor hp (nullable)
  final String? profileImage;   // url foto profil
  final List<String> favoriteBarbershops;  // list id barbershop favorit
  final String? barbershopId;   // jika user adalah admin/barber
  final String role;            // "customer", "barber", atau "admin"
}
```
- Merepresentasikan satu user
- role: menentukan apa yang bisa diakses user
- favoriteBarbershops: list barbershop yang di-favorite

#### 6. BookingDetails Model
```dart
class BookingDetails {
  final Queue queue;                    // object queue
  final String barbershopName;          // nama barbershop (dari barbershop collection)
  final String barbermanName;           // nama barber (dari barberman collection)
  final String serviceName;             // nama service (dari service collection)
  final String barbershopImage;         // url image barbershop
}
```
- Gabungan data dari Queue + Barbershop + Barberman + Service
- Digunakan untuk menampilkan detail booking dengan semua info lengkap
- Ini bukan model firebase (tidak disimpan di database)

#### 7. PromoBanner Model
```dart
class PromoBanner {
  final String id;              // id banner
  final String title;           // judul promo
  final String subtitle;        // subtitle promo
  final String imageUrl;        // url gambar promo
  final bool isActive;          // apakah promo sedang aktif
}
```
- Merepresentasikan satu banner promo
- Ditampilkan di carousel di home screen

### Cara Membuat Object dari Model

```dart
// cara 1: constructor normal
final barbershop = Barbershop(
  id: "1",
  name: "Barber Premium",
  addres: "Jl. Sudirman",
  rating: 4.5,
  imageUrl: "https://...",
  services: ["s1", "s2"],
  openHour: 9,
  closeHour: 21,
  isOpen: true,
);

// cara 2: dari firebase data
final doc = await firestore.collection('barbershops').doc('1').get();
final barbershop = Barbershop.fromFirestore(doc);

// cara 3: dari map/json
final barbershop = Barbershop.fromJson({
  "id": "1",
  "name": "Barber Premium",
  ...
});
```

### Nullable vs Non-Nullable

```dart
final String name;        // non-nullable: harus ada value, tidak boleh null
final String? address;    // nullable: boleh null (?)

// di constructor
Queue({
  required this.id,       // required: harus diberikan saat create object
  this.startTime,         // optional: bisa tidak diberikan (default null jika nullable)
})
```

---

## PENJELASAN SERVICES (Logika Backend)

### Apa itu Service?

Service adalah class yang menangani:
1. Komunikasi dengan Firebase (ambil data, simpan data, update, delete)
2. Logika bisnis (validasi, processing, dll)

Service adalah "middle layer" antara UI (screen) dan Database (firebase).

### Arsitektur Data Flow

```
UI Screen (contoh: HomeScreen)
    ↓
Service (contoh: BarbershopService)
    ↓
Firebase (firestore, authentication, storage)
```

### Service yang Ada

#### 1. BarbershopService
```dart
class BarbershopService {
  // ambil semua barbershop
  Future<List<Barbershop>> getAllBarbershops() async {
    // 1. query collection 'barbershops' di firebase
    // 2. convert setiap document menjadi object Barbershop
    // 3. return list<Barbershop>
  }
  
  // ambil barbershop by id
  Future<Barbershop?> getBarbershopById(String id) async { ... }
  
  // ambil stream promo banners (realtime updates)
  Stream<List<PromoBanner>> getPromoBanners() {
    // return stream dari collection 'promo_banners'
    // setiap perubahan data akan di-broadcast ke listener
  }
  
  // ambil barber di barbershop tertentu
  Future<List<Barberman>> getBarbermenByShop(String shopId) async { ... }
  
  // ambil semua service
  Future<List<Service>> getAllServices() async { ... }
}
```
- Menangani semua operasi related ke barbershop
- Future: return sekali saja (async task)
- Stream: return realtime updates (async task yang terus berlanjut)

#### 2. QueueService (Booking Service)
```dart
class QueueService {
  // tambah booking baru
  Future<String> addQueue(Queue queue) async {
    // 1. validasi slot availability (apakah barber bisa potong pada waktu tsb)
    // 2. jika ada slot, simpan queue ke firebase
    // 3. return queue id
  }
  
  // ambil queue by id
  Future<Queue?> getQueueById(String queueId) async { ... }
  
  // ambil stream queue untuk customer tertentu
  Stream<List<Queue>> streamQueuesForCustomer(String customerId, {required List<String> statusFilter}) {
    // return stream queue dengan filter status (waiting, booked, dll)
  }
  
  // update status queue (contoh: waiting → booked → ongoing)
  Future<void> updateQueueStatus(String queueId, QueueStatus status) async { ... }
  
  // validasi slot (apakah barber bisa melayani pada waktu itu)
  Future<bool> isSlotAvailable(String barbermanId, DateTime startTime, int durationMinutes) async { ... }
}
```
- Menangani semua operasi booking
- Validasi slot sangat penting (jangan ada double booking)

#### 3. AuthService (Authentication Service)
```dart
class AuthService {
  // login
  Future<UserData?> loginWithEmail(String email, String password) async {
    // 1. authenticate dengan firebase auth
    // 2. ambil user data dari firestore
    // 3. return UserData object
  }
  
  // register
  Future<UserData?> registerWithEmail(String email, String password, String name) async {
    // 1. buat account di firebase auth
    // 2. simpan user data ke firestore
    // 3. return UserData object
  }
  
  // logout
  Future<void> logout() async { ... }
  
  // get current user
  UserData? getCurrentUser() { ... }
  
  // get current user stream (realtime)
  Stream<UserData?> getCurrentUserStream() { ... }
}
```
- Menangani login, register, logout
- getCurrentUser: untuk cek apakah user sudah login

#### 4. BarbermanService
```dart
class BarbermanService {
  // ambil semua barberman
  Future<List<Barberman>> getAllBarbermen() async { ... }
  
  // ambil barberman by id
  Future<Barberman?> getBarbermanById(String id) async { ... }
  
  // ambil barberman di barbershop tertentu
  Future<List<Barberman>> getBarbermansByShop(String shopId) async { ... }
}
```
- Menangani data barber
- Lebih sederhana dari BarbershopService

### Implementasi Service Method (Contoh)

```dart
// Contoh: getAllBarbershops
Future<List<Barbershop>> getAllBarbershops() async {
  try {
    // 1. query collection 'barbershops'
    final snapshot = await FirebaseFirestore.instance
        .collection('barbershops')
        .get();
    
    // 2. convert setiap document ke Barbershop object
    final barbershops = snapshot.docs
        .map((doc) => Barbershop.fromFirestore(doc))
        .toList();
    
    // 3. return list
    return barbershops;
  } catch (e) {
    print("Error fetching barbershops: $e");
    return [];  // return empty list jika error
  }
}

// Contoh: streamQueuesForCustomer
Stream<List<Queue>> streamQueuesForCustomer(
  String customerId, {
  required List<String> statusFilter,
}) {
  // 1. query collection 'queues' dengan filter
  // 2. listen pada perubahan data
  // 3. setiap ada perubahan, emit list baru
  return FirebaseFirestore.instance
      .collection('queues')
      .where('customer_id', isEqualTo: customerId)
      .where('status', whereIn: statusFilter)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Queue.fromFirestore(doc))
          .toList());
}

// Contoh: validasi slot
Future<bool> isSlotAvailable(
  String barbermanId,
  DateTime startTime,
  int durationMinutes,
) async {
  try {
    // 1. query queue untuk barberman ini pada waktu tsb
    final snapshot = await FirebaseFirestore.instance
        .collection('queues')
        .where('barberman_id', isEqualTo: barbermanId)
        .where('status', whereIn: ['booked', 'ongoing'])
        .get();
    
    // 2. cek ada konflik waktu tidak
    final endTime = startTime.add(Duration(minutes: durationMinutes));
    
    for (final doc in snapshot.docs) {
      final queue = Queue.fromFirestore(doc);
      final queueStart = queue.bookingTime.toDate();
      final queueEnd = queueStart.add(
        Duration(minutes: queue.estimatedDuration ?? 30)
      );
      
      // cek overlap
      if (startTime.isBefore(queueEnd) && endTime.isAfter(queueStart)) {
        return false;  // ada konflik
      }
    }
    
    return true;  // slot available
  } catch (e) {
    print("Error checking slot: $e");
    return false;
  }
}
```

---

## PENJELASAN SCREENS (Halaman UI)

### Apa itu Screen?

Screen adalah halaman/layar di aplikasi. Setiap screen adalah satu StatefulWidget atau StatelessWidget.

### Lifecycle Screen

```
initState() → dipanggil 1x saat screen pertama kali dibuat
    ↓
build() → dipanggil saat screen perlu rebuild (setState())
    ↓
dispose() → dipanggil saat screen ditutup/dihapus
```

### Screen yang Ada

#### 1. HomeScreen (lib/screens/customer/home_screen.dart)
**Deskripsi:** Halaman utama customer dengan 4 tab

**Struktur:**
- Tab 1: Home (list barbershop + promo)
- Tab 2: StyleScan (AI scan gaya rambut)
- Tab 3: Chatbot (AI assistant)
- Tab 4: Profile (profil user)

**Components:**
```dart
HomeScreen
├── PageView (untuk swipe 4 tab)
│   ├── _buildHomePageBody() → Tab 1
│   │   ├── _buildHeader() (greeting + notification)
│   │   ├── _buildSearchBar() (search barbershop)
│   │   ├── PromoCarousel (slider banner)
│   │   └── _buildRecommendedList() (barbershop list)
│   │       └── _buildBarbershopCard() (untuk setiap barbershop)
│   ├── StyleScanScreen() → Tab 2
│   ├── ChatAssistantScreen() → Tab 3
│   └── ProfileScreen() → Tab 4
└── BottomNavigationBar (tombol tab di bawah)
```

**State Variables:**
```dart
int _selectedIndex = 0;                           // tab mana yang aktif
late Future<List<Barbershop>> _barbershopFuture;  // data barbershop
```

**Key Methods:**
```dart
initState() {
  // ambil data barbershop saat screen dibuka
  _barbershopFuture = _barbershopService.getAllBarbershops();
}

void _onItemTapped(int index) {
  // handle tap tab
  setState(() => _selectedIndex = index);
  _pageController.jumpToPage(index);
}

Widget _buildRecommendedList() {
  // tampilkan list barbershop dengan FutureBuilder
  return FutureBuilder<List<Barbershop>>(
    future: _barbershopFuture,
    builder: (context, snapshot) {
      // loading state
      // error state
      // success state
    }
  );
}
```

**Navigation:**
- Tap barbershop card → BarbershopDetailScreen
- Tap profile tab → ProfileScreen

#### 2. BarbershopDetailScreen
**Deskripsi:** Detail halaman satu barbershop (info, service, review)

**Struktur:**
```dart
BarbershopDetailScreen
├── NestedScrollView
│   ├── Header (SliverAppBar)
│   │   ├── Barbershop image
│   │   └── TabBar (3 tab: About, Services, Review)
│   └── Body
│       ├── AboutTab (deskripsi barbershop)
│       ├── ServicesTab (list layanan)
│       └── ReviewTab (review dari customer)
└── BottomNavigationBar
    ├── Rating + address
    └── "Book Now" button
```

**State Variables:**
```dart
late TabController _tabController;
int _reviewCount = 0;
bool _isFavorite = false;
```

**Key Methods:**
```dart
Future<void> _fetchReviewCount() {
  // ambil jumlah review dari firebase
}

Future<void> _checkIfFavorite() {
  // cek apakah barbershop ini di-favorite user
}

Future<void> _toggleFavorite() {
  // toggle favorite status
  // tambah/hapus dari array favoriteBarbershops di user doc
}

void _goToAppointment() {
  // navigate ke appointment screen untuk booking
  Navigator.push(context, MaterialPageRoute(
    builder: (context) => AppointmentScreen(barbershop: widget.barbershop)
  ));
}
```

**Navigation:**
- Tap "Book Now" → AppointmentScreen
- Swipe tab → AboutTab / ServicesTab / ReviewTab
- Back button → HomeScreen

#### 3. AppointmentScreen
**Deskripsi:** Halaman booking (pilih barber, service, waktu)

**Struktur:**
```dart
AppointmentScreen
├── Form
│   ├── Select barbershop (sudah auto-filled)
│   ├── Select barber (dropdown)
│   ├── Select service(s) (checkboxes)
│   ├── Select date & time (date/time picker)
│   ├── Show total price & duration
│   └── Notes (optional)
└── "Continue to Payment" button
```

**State Variables:**
```dart
List<Barberman> _barbermen = [];
List<Service> _services = [];
Barberman? _selectedBarberman;
List<String> _selectedServiceIds = [];
DateTime? _selectedDateTime;
```

**Key Methods:**
```dart
Future<void> _initData() {
  // ambil data barberman & service untuk barbershop ini
}

Future<void> _pickDateTime() {
  // tampilkan date picker & time picker
  // validasi: tidak boleh di masa lalu, harus dalam jam buka
}

int get _totalPrice {
  // hitung total harga dari service yang dipilih
}

Future<void> _onSubmit() {
  // validasi form
  // check slot availability
  // simpan ke firebase
  // navigate ke payment screen
}
```

**Navigation:**
- Tap "Continue to Payment" → PaymentScreen

#### 4. PaymentScreen
**Deskripsi:** Halaman pembayaran

**Struktur:**
```dart
PaymentScreen
├── Order summary
│   ├── Barbershop name
│   ├── Barber name
│   ├── Service(s) & price
│   ├── Date & time
│   └── Total
├── Payment method selection
│   ├── Credit card
│   ├── E-wallet
│   ├── Bank transfer
│   └── Cash at store
└── "Pay" button
```

**Navigation:**
- Tap "Pay" → booking confirmation → HomeScreen

#### 5. ProfileScreen
**Deskripsi:** Profil user

**Struktur:**
```dart
ProfileScreen
├── Profile header
│   ├── Avatar image
│   └── Name & email
├── Menu
│   ├── My Bookings
│   ├── Favorite Barbershops
│   ├── Edit Profile
│   ├── Settings
│   └── Logout
```

**Navigation:**
- Tap "My Bookings" → MyBookingsScreen
- Tap "Favorite Barbershops" → FavoriteBarber shopsScreen
- Tap "Edit Profile" → EditProfileScreen
- Tap "Logout" → LoginScreen

#### 6. AdminDashboard
**Deskripsi:** Halaman dashboard admin (lihat antrian live, management booking)

**Struktur:**
```dart
AdminDashboard
├── Today's summary
│   ├── Total customers today
│   ├── Completed bookings
│   ├── Revenue
├── Live queue (realtime)
│   ├── Queue list dengan status
│   └── Update status options
└── Actions
    ├── Add manual booking
    └── Manage services
```

---

## STYLING DAN TEMA

### Tema Global (main.dart)

```dart
theme: ThemeData.dark().copyWith(
  primaryColor: Color(0xFFC3A47B),        // coklat main
  scaffoldBackgroundColor: Colors.black,  // background hitam
  colorScheme: ColorScheme.dark(
    primary: Color(0xFFC3A47B),
    secondary: Color(0xFFC3A47B),
    surface: Color(0xFF1E1E1E),          // abu-abu gelap (card bg)
    onPrimary: Colors.black,              // teks di atas coklat
    onSurface: Colors.white,              // teks utama
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(...),
  inputDecorationTheme: InputDecorationTheme(...),
)
```

### Palet Warna

```dart
// Static constants di setiap screen
static const Color kBrownAccent = Color(0xFFC3A47B);    // coklat
static const Color kBlackBackground = Colors.black;     // hitam
static const Color kDarkGrey = Color(0xFF1E1E1E);       // abu-abu gelap
static const Color kSurface = Colors.black;             // surface
static const Color kTextGrey = Colors.white70;          // text secondary
```

### Hex Color Format

```dart
Color(0xFFRRGGBB)
// FF = fully opaque (tidak transparan)
// RR = red (00-FF)
// GG = green (00-FF)
// BB = blue (00-FF)

// Contoh:
Color(0xFFC3A47B)  // coklat
Color(0xFF1E1E1E)  // abu gelap
Color(0xFF000000)  // hitam
Color(0xFFFFFFFF)  // putih
Color(0x80000000)  // hitam 50% transparan
```

### Border & Radius

```dart
// Rounded corner
BorderRadius.circular(15)              // semua sudut 15 px
BorderRadius.only(
  topLeft: Radius.circular(15),
  topRight: Radius.circular(15),
)

// Border
Border.all(color: Colors.black, width: 1)
Border(
  bottom: BorderSide(color: Colors.black, width: 1)
)
```

### Shadow & Elevation

```dart
// BoxShadow
boxShadow: [
  BoxShadow(
    color: Colors.black.withOpacity(0.2),
    blurRadius: 5,
    offset: Offset(0, 2),
  )
]

// Elevation (di AppBar, Card, dll)
elevation: 0  // tidak ada shadow
elevation: 4  // shadow sedang
```

### Padding & Margin

```dart
EdgeInsets.all(16)                           // semua sisi 16
EdgeInsets.symmetric(horizontal: 16, vertical: 8)
EdgeInsets.only(left: 16, right: 16, top: 8)
EdgeInsets.fromLTRB(16, 8, 16, 8)           // left, top, right, bottom

// Di Widget
Padding(padding: EdgeInsets.all(16), child: ...)
Container(margin: EdgeInsets.all(8), ...)
```

### Text Styling

```dart
TextStyle(
  color: Colors.white,
  fontSize: 18,
  fontWeight: FontWeight.bold,         // tebal
  fontStyle: FontStyle.italic,         // miring
  letterSpacing: 0.5,                  // jarak huruf
  wordSpacing: 2,                      // jarak kata
  decoration: TextDecoration.underline // garis bawah
)
```

### BoxFit (Image Sizing)

```dart
BoxFit.cover      // stretch image untuk fill container (bisa crop)
BoxFit.contain    // fit image dalam container (bisa ada space)
BoxFit.fill       // stretch untuk fill (bisa distort)
BoxFit.fitWidth   // fit lebar
BoxFit.fitHeight  // fit tinggi
```

---

## NAVIGASI ANTAR HALAMAN

### Cara Navigasi di Flutter

#### 1. Push (Tambah halaman baru)
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => ScreenBaru())
);
```
- Stack navigation (halaman baru di atas halaman sebelumnya)
- User bisa back/kembali ke halaman sebelumnya

#### 2. PushReplacement (Ganti halaman)
```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => ScreenBaru())
);
```
- Hapus halaman current, ganti dengan halaman baru
- User tidak bisa kembali ke halaman yang dihapus

#### 3. Pop (Kembali)
```dart
Navigator.pop(context)
Navigator.pop(context, returnValue)  // pop dengan return value
```
- Kembali ke halaman sebelumnya

#### 4. Named Routes (Recommended)
```dart
// Setup di main.dart
MaterialApp(
  routes: {
    '/home': (context) => HomeScreen(),
    '/login': (context) => LoginScreen(),
  },
)

// Navigation
Navigator.pushNamed(context, '/home');
Navigator.pushReplacementNamed(context, '/login');
Navigator.popAndPushNamed(context, '/home');
```

### Navigasi di Aplikasi Ini

```
OnboardingScreen
    ↓ skip / next
LoginScreen / RegisterScreen
    ↓ login berhasil
HomeScreen (4 tab navigation)
    ├── Home Tab
    │   ├── tap barbershop card
    │   └── → BarbershopDetailScreen
    │       ├── tap "Book Now"
    │       └── → AppointmentScreen
    │           ├── select service & time
    │           ├── tap "Continue"
    │           └── → PaymentScreen
    │               ├── tap "Pay"
    │               └── → Booking confirmation
    │
    ├── StyleScan Tab
    │   └── Scan gaya rambut dengan AI
    │
    ├── Chatbot Tab
    │   └── Chat dengan AI assistant
    │
    └── Profile Tab
        ├── tap "My Bookings"
        │   └── → MyBookingsScreen (lihat booking active & history)
        ├── tap "Favorite Barbershops"
        │   └── → FavoriteBarber shopsScreen
        └── tap "Edit Profile"
            └── → EditProfileScreen
```

### Best Practices

1. **Selalu passing context yang benar**
   ```dart
   Navigator.push(context, ...)  // context harus dari widget yang ingin navigate
   ```

2. **Return value dari screen**
   ```dart
   // screen A
   final result = await Navigator.push(context, ...);
   
   // screen B
   Navigator.pop(context, "returned value");
   ```

3. **Avoid memory leak**
   ```dart
   // dispose navigator ketika tidak digunakan
   // contoh: dispose stream, timer, controller
   @override
   void dispose() {
     streamSub?.cancel();
     controller.dispose();
     super.dispose();
   }
   ```

---

## RINGKASAN

### Alur Mengerti Aplikasi

1. **Mulai dari main.dart** - Setup tema, firebase, halaman pertama
2. **Pahami Models** - Struktur data yang digunakan
3. **Pahami Services** - Logika bisnis & komunikasi firebase
4. **Pahami Screens** - UI dan bagaimana user berinteraksi
5. **Pahami Navigasi** - Bagaimana pindah antar halaman
6. **Pahami Widgets** - Component UI yang digunakan

### Key Concepts

- **Widget**: Component UI (stateless = tidak berubah, stateful = bisa berubah)
- **Model**: Blueprint struktur data
- **Service**: Logika & komunikasi dengan database
- **Screen**: Halaman UI yang bisa user lihat
- **Navigation**: Cara pindah antar halaman
- **State Management**: Bagaimana mengelola data yang berubah (setState, Provider, dll)
- **Async/Await**: Cara handle operasi yang butuh waktu (load data dari firebase)
- **Stream**: Realtime updates dari database

### Implementasi Fitur Baru

Jika ingin implementasi fitur baru:

1. **Design Model** - Tentukan data structure
2. **Design Service** - Tentukan operasi database yang diperlukan
3. **Design UI** - Sketch halaman & component
4. **Implement Model** - Buat class model
5. **Implement Service** - Buat method di service
6. **Implement Screen** - Buat UI dengan memanggil service
7. **Connect Navigation** - Link dengan halaman lain
8. **Test** - Test feature dari awal sampai selesai

