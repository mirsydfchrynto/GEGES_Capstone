# DOKUMENTASI MY BOOKINGS SCREEN

## Lokasi File
`lib/screens/customer/tabs/my_bookings_screen.dart`

## Deskripsi
MyBookingsScreen menampilkan daftar booking customer dalam 2 tab:
- Active: booking yang masih berlangsung (waiting, booked, ongoing)
- History: booking yang sudah selesai (served, cancelled)

## Features
- Tab navigation (active vs history)
- Realtime updates menggunakan StreamBuilder
- Fetch detail booking dari multiple collections (queue, barbershop, barberman, service)
- Show loading, error, dan empty states
- Display booking status dengan warna berbeda

## Struktur Code

```dart
// =====================================================
// CONSTANTS & THEME
// =====================================================
const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;

// penjelasan:
// - const berarti constant (tidak berubah)
// - disimpan di level file (bukan dalam class) agar bisa diakses dimana saja
// - warna ini digunakan untuk styling konsisten di seluruh screen
```

## Main Widget

```dart
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

// penjelasan:
// - MyBookingsScreen adalah stateful widget karena perlu track tab state
// - createstate() return instance dari state class
```

## State Class

```dart
class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  // penjelasan singletickerproviderstaticmixin:
  // - mixin untuk provide ticker untuk satu animation
  // - needed untuk tabcontroller (tab animation)
  // - jika ada lebih dari 1 animation, gunakan TickerProviderStateMixin
  
  late TabController _tabController;
  
  // penjelasan late:
  // - variable akan diinisialisasi nanti di initstate
  // - bukan di constructor (karena perlu vsync dari state)
  
  final QueueService _queueService = QueueService();
  // instance dari queue service untuk ambil booking data
  
  final String? _customerId = FirebaseAuth.instance.currentUser?.uid;
  // get current user id dari firebase auth
  // nullable (?) karena user mungkin tidak login (tapi di practice ini seharusnya always logged in)

  @override
  void initState() {
    super.initState();
    // inisialisasi tab controller dengan 2 tab
    // vsync: this = provide ticker dari state untuk animasi
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();  // cleanup tabcontroller
    super.dispose();
  }
```

## Key Method: _fetchDetailsForQueue()

```dart
/// penjelasan method:
/// - async method yang mengambil detail booking lengkap
/// - input: queue object (dari firestore)
/// - output: bookingdetails object (queue + barbershop + barberman + service info)
/// - alasan: queue di firestore hanya contain id, bukan nama/info
/// - kita perlu query collection lain untuk ambil nama dan info
Future<BookingDetails> _fetchDetailsForQueue(Queue queue) async {
  // url gambar default jika tidak ada
  const String defaultImage =
      'https://cdn-icons-png.flaticon.com/512/706/706830.png';

  try {
    // inisialisasi dengan default value
    String barbershopName = 'Barbershop Dihapus';  // jika barbershop dihapus dari db
    String barbershopImage = defaultImage;
    String barbermanName = 'Barberman Dihapus';    // jika barber dihapus dari db
    String serviceName = 'Layanan Dihapus';       // jika service dihapus dari db

    // =====================================================
    // step 1: ambil data barbershop
    // =====================================================
    final bsDoc = await FirebaseFirestore.instance
        .collection('barbershops')
        .doc(queue.barbershopId)
        .get();
    if (bsDoc.exists) {
      // jika document ada, ambil name dan imageurl
      barbershopName = bsDoc.data()?['name'] ?? barbershopName;
      barbershopImage = bsDoc.data()?['imageUrl'] ?? defaultImage;
    }
    // jika document tidak ada, gunakan default value yang sudah di-set

    // =====================================================
    // step 2: ambil data barberman
    // =====================================================
    final bmDoc = await FirebaseFirestore.instance
        .collection('barbermen')
        .doc(queue.barbermanId)
        .get();
    if (bmDoc.exists) {
      barbermanName = bmDoc.data()?['name'] ?? barbermanName;
    }

    // =====================================================
    // step 3: ambil data service
    // =====================================================
    final serviceId = queue.firstServiceId;  // ambil service id pertama dari queue
    if (serviceId != null) {
      final svDoc = await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .get();
      if (svDoc.exists) {
        serviceName = svDoc.data()?['name'] ?? serviceName;

        // penjelasan: jika ada lebih dari 1 service
        // tampilkan "Service1, Service2, ..." untuk itu cek serviceids.length > 1
        if (queue.serviceIds != null && queue.serviceIds!.length > 1) {
          serviceName = '$serviceName (+${queue.serviceIds!.length - 1} more)';
          // contoh: "Potong Rambut (+1 more)" jika ada 2 service
        }
      }
    }

    // =====================================================
    // return booking details object
    // =====================================================
    return BookingDetails(
      queue: queue,
      barbershopName: barbershopName,
      barbermanName: barbermanName,
      serviceName: serviceName,
      barbershopImage: barbershopImage,
    );
  } catch (e) {
    // handle error: jika ada exception saat fetch
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
```

## UI: Build Method

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: kSurface,  // warna latar hitam
    appBar: AppBar(
      backgroundColor: kSurface,
      foregroundColor: Colors.white,
      elevation: 0,  // tanpa shadow
      title: const Text(
        'My Bookings',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
      ),
      // tab bar di bawah app bar
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: kBrownAccent,  // warna garis indicator (coklat)
        labelColor: kBrownAccent,      // warna tab text yang aktif
        unselectedLabelColor: kTextGrey,  // warna tab text yang tidak aktif
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        tabs: const [
          Tab(text: 'Active'),      // tab 1: booking aktif
          Tab(text: 'History'),     // tab 2: booking history
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [
        _buildBookingList(isCompleted: false),  // active bookings
        _buildBookingList(isCompleted: true),   // completed bookings
      ],
    ),
  );
}
```

## Key Widget: _buildBookingList()

```dart
/// penjelasan:
/// - build list booking dengan filter status
/// - isCompleted parameter untuk tentukan filter (active vs history)
/// - return streambuilder untuk realtime updates
Widget _buildBookingList({required bool isCompleted}) {
  // =====================================================
  // step 1: validasi user sudah login
  // =====================================================
  if (_customerId == null) {
    return const Center(
      child: Text(
        'Anda harus login untuk melihat booking.',
        style: TextStyle(color: kTextGrey, fontSize: 16),
      ),
    );
  }

  // =====================================================
  // step 2: tentukan filter status berdasarkan isCompleted
  // =====================================================
  // penjelasan logic:
  // - isCompleted = true → active bookings (waiting, booked, ongoing)
  // - isCompleted = false → history bookings (served, cancelled)
  final List<String> requiredStatus = isCompleted
      ? ['served', 'cancelled']            // history
      : ['waiting', 'booked', 'ongoing'];  // active

  // =====================================================
  // step 3: ambil stream booking dari service
  // =====================================================
  // streamqueuessforcustomer: listen pada queue yang match filter
  // return stream, bukan future (realtime updates)
  final Stream<List<Queue>> queueStream =
      _queueService.streamQueuesForCustomer(_customerId!, statusFilter: requiredStatus);

  // =====================================================
  // step 4: return streambuilder untuk handle stream
  // =====================================================
  return StreamBuilder<List<Queue>>(
    stream: queueStream,
    builder: (context, snapshot) {
      // penjelasan connectionstate:
      // - waiting: stream sedang connect/load, belum ada data
      // - active: stream connected, ada data
      // - done: stream closed
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: kBrownAccent),
        );
      }

      // handle error dari stream
      if (snapshot.hasError) {
        return Center(
          child: Text(
            'Error: ${snapshot.error}',
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        );
      }

      // ambil queue list dari snapshot
      // ?? [] = jika data null, gunakan empty list
      final filteredList = snapshot.data ?? [];

      // handle empty list (tidak ada booking)
      if (filteredList.isEmpty) {
        return _buildEmptyState(isCompleted);
      }

      // build list view dari queue
      return ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final queue = filteredList[index];
          // untuk setiap queue, build card
          return _buildBookingCard(context, queue);
        },
      );
    },
  );
}
```

## Key Widget: _buildBookingCard()

```dart
/// penjelasan:
/// - build satu card untuk satu booking
/// - menggunakan futurebuilder untuk fetch detail booking
Widget _buildBookingCard(BuildContext context, Queue queue) {
  return FutureBuilder<BookingDetails>(
    future: _fetchDetailsForQueue(queue),  // fetch detail async
    builder: (context, snapshot) {
      // loading state: sedang fetch detail
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildLoadingCard();
      }

      // error state: error saat fetch
      if (snapshot.hasError || !snapshot.hasData) {
        debugPrint('Error loading detail for queue ${queue.id}: ${snapshot.error}');
        return _buildErrorCard(queue.id, snapshot.error);
      }

      // success state: data sudah ada
      final details = snapshot.data!;
      final QueueStatus status = details.queue.status;

      // format status untuk display (uppercase)
      final displayStatus = status.value.toUpperCase();

      // helper variables
      final isServed = status == QueueStatus.served;
      final isPendingOrWaiting = status == QueueStatus.waiting || status == QueueStatus.booked;

      // penjelasan getstatuscolor:
      // - return warna berdasarkan status
      // - serve = green (selesai)
      // - waiting/booked = amber (pending)
      // - ongoing = blue (sedang proses)
      // - cancelled = red (dibatalkan)
      Color getStatusColor() {
        switch (status) {
          case QueueStatus.served:
            return Colors.green;
          case QueueStatus.waiting:
          case QueueStatus.booked:
            return Colors.amber;
          case QueueStatus.ongoing:
            return Colors.blue;
          case QueueStatus.cancelled:
            return Colors.red;
        }
      }

      // helper function untuk format timestamp
      String formatTimestamp(Timestamp t) {
        return DateFormat('EEE, d MMM yyyy, HH:mm').format(t.toDate());
      }

      // build card container
      return Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: getStatusColor(), width: 1),  // border warna sesuai status
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =====================================================
            // row 1: barbershop info + status badge
            // =====================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // barbershop image + name
                Expanded(
                  child: Row(
                    children: [
                      // image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: CachedNetworkImage(
                            imageUrl: details.barbershopImage,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(color: Colors.grey),
                            errorWidget: (c, u, e) => const Icon(Icons.error),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // name + barber
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              details.barbershopName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Barber: ${details.barbermanName}',
                              style: const TextStyle(color: kTextGrey, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: getStatusColor(),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    displayStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // =====================================================
            // row 2-5: detail info (service, time, price, duration)
            // =====================================================
            _buildDetailRow('Service', details.serviceName),
            _buildDetailRow('Date & Time', formatTimestamp(details.queue.bookingTime)),
            _buildDetailRow(
              'Price',
              'Rp ${details.queue.totalPrice ?? 0}',
              isAccent: true,  // highlight text dengan warna accent
            ),
            _buildDetailRow(
              'Duration',
              '${details.queue.estimatedDuration ?? 30} min',
            ),
          ],
        ),
      );
    },
  );
}
```

## Helper Widgets

```dart
/// penjelasan _buildemptystate:
/// - tampilkan pesan ketika tidak ada booking
Widget _buildEmptyState(bool isCompleted) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isCompleted ? Icons.history : Icons.calendar_today,
          size: 60,
          color: kTextGrey,
        ),
        const SizedBox(height: 16),
        Text(
          isCompleted ? 'Tidak ada history' : 'Tidak ada booking aktif',
          style: const TextStyle(color: kTextGrey, fontSize: 16),
        ),
      ],
    ),
  );
}

/// penjelasan _buildloadingcard:
/// - tampilkan loading skeleton saat fetch detail
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

/// penjelasan _builderrorcard:
/// - tampilkan error card jika gagal fetch detail
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
        Text(
          'Gagal memuat detail: $queueId',
          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Text(
          'Error: ${error?.toString().split(':').last.trim() ?? "Unknown error"}',
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ],
    ),
  );
}

/// penjelasan _builddetailrow:
/// - widget untuk tampilkan label + value
/// - isAccent: jika true, value ditampilkan dengan warna accent
Widget _buildDetailRow(String label, String value, {bool isAccent = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: kTextGrey, fontSize: 14),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: isAccent ? kBrownAccent : Colors.white,
              fontSize: 14,
              fontWeight: isAccent ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// penjelasan _showsnackbar:
/// - tampilkan notification di bawah layar
void _showSnackbar(BuildContext context, String message, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      duration: const Duration(seconds: 1),
    ),
  );
}
```

## Data Flow

```
MyBookingsScreen
    ↓
build() → AppBar + TabBar + TabBarView
    ↓
TabBarView dengan 2 children:
    ├── _buildBookingList(isCompleted: false)
    │   ↓
    │   StreamBuilder listen pada queuestream (active bookings)
    │   ├── waiting state: tampilkan loading spinner
    │   ├── error state: tampilkan error message
    │   ├── empty state: tampilkan "no active booking" message
    │   └── data state: ListView.builder
    │       ├── untuk setiap queue item
    │       ├── build _buildBookingCard()
    │       │   ↓
    │       │   FutureBuilder fetch detail (barbershop, barber, service)
    │       │   ├── loading: tampilkan skeleton card
    │       │   ├── error: tampilkan error card
    │       │   └── success: tampilkan detail card
    │       └── build card dengan image, name, barber, status, detail info
    │
    └── _buildBookingList(isCompleted: true)
        ↓
        sama seperti active, tapi dengan filter status served/cancelled
```

## Best Practices

1. **Always Check Mounted**
   ```dart
   if (!mounted) return;
   ```

2. **Handle Null Values Gracefully**
   ```dart
   final value = snapshot.data ?? defaultValue;
   ```

3. **Use FutureBuilder untuk Async Tasks**
   ```dart
   FutureBuilder<T>(
     future: asyncTask(),
     builder: (context, snapshot) {
       if (snapshot.connectionState == ConnectionState.waiting) {
         // loading
       }
     }
   )
   ```

4. **Use StreamBuilder untuk Realtime Updates**
   ```dart
   StreamBuilder<T>(
     stream: realtimeStream(),
     builder: (context, snapshot) {
       // update otomatis setiap ada perubahan data
     }
   )
   ```

5. **Format Display Data dengan Benar**
   ```dart
   DateFormat('EEE, d MMM yyyy, HH:mm').format(timestamp.toDate());
   ```

