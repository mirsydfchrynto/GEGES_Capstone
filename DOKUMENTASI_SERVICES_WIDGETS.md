# DOKUMENTASI SERVICES & WIDGETS

## Pengantar
Services adalah layer yang menghubungkan UI dengan Firebase backend. Widgets adalah reusable UI components.

---

## SERVICES LAYER

### Deskripsi Umum
Services folder berisi 5 service classes untuk handle business logic & firebase operations:
1. **AuthService** - User authentication & profile management
2. **BarbershopService** - Barbershop & service data
3. **QueueService** - Booking queue management
4. **BarbermanService** - Barber data management
5. **ServiceService** - Service package management

---

## 1. auth_service.dart

### Deskripsi
AuthService menangani user authentication (login, register, google sign in, password reset) dan user profile management.

### Key Methods

```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // penjelasan:
  // - _auth: firebase authentication instance
  // - _firestore: firebase firestore instance

  // =====================================================
  // GETTER: Current User
  // =====================================================
  User? get currentUser => _auth.currentUser;
  // penjelasan:
  // - return firebase auth user (jika sudah login)
  // - return null jika belum login

  // =====================================================
  // METHOD: Sign In (Email/Password)
  // =====================================================
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    // penjelasan:
    // - login menggunakan email & password
    // - validate credentials di firebase auth
    // - fetch user role dari firestore
    // - return {'success': bool, 'role': string, 'message': string}

    try {
      // step 1: sign in ke firebase auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // step 2: ambil uid dari credential
      final uid = userCredential.user!.uid;

      // step 3: fetch user data dari firestore untuk ambil role
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        return {
          'success': false,
          'message': 'data pengguna tidak ditemukan.',
        };
      }

      // step 4: ambil role dari user document
      final data = doc.data() as Map<String, dynamic>;
      final role = (data['role'] as String?) ?? 'customer';

      // step 5: return success dengan role
      return {
        'success': true,
        'role': role,
      };
    } on FirebaseAuthException catch (e) {
      // handle firebase-specific errors
      return {
        'success': false,
        'message': e.message ?? 'login gagal',
      };
    } catch (e) {
      // handle general errors
      return {
        'success': false,
        'message': 'terjadi kesalahan saat login: $e',
      };
    }
  }

  // =====================================================
  // METHOD: Register (Email/Password)
  // =====================================================
  Future<Map<String, dynamic>> registerCustomer({
    required String email,
    required String password,
    required String name,
  }) async {
    // penjelasan:
    // - register user baru dengan email & password
    // - create user di firebase auth
    // - create user document di firestore
    // - send email verification (optional)

    try {
      // step 1: create user di firebase auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // step 2: update display name
      await userCredential.user?.updateDisplayName(name);

      // step 3: create user document di firestore
      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'role': 'customer',
        'created_at': FieldValue.serverTimestamp(),
      });

      // step 4: send email verification (optional)
      await userCredential.user?.sendEmailVerification();

      return {
        'success': true,
        'message': 'registrasi berhasil. silakan verifikasi email anda.',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'registrasi gagal',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'terjadi kesalahan saat registrasi: $e',
      };
    }
  }

  // =====================================================
  // METHOD: Sign In with Google
  // =====================================================
  Future<Map<String, dynamic>> signInWithGoogle() async {
    // penjelasan:
    // - login menggunakan google account
    // - jika user baru, create user document di firestore
    // - return {'success': bool, 'role': string, 'message': string}

    try {
      final googleSignIn = GoogleSignIn(scopes: <String>['email', 'profile']);
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // user cancel google sign in
        return {
          'success': false,
          'message': 'google sign in dibatalkan',
        };
      }

      // ambil google auth dari user
      final googleAuth = await googleUser.authentication;

      // create credential untuk firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // sign in ke firebase dengan google credential
      final userCredential = await _auth.signInWithCredential(credential);
      final uid = userCredential.user!.uid;

      // check apakah user sudah ada di firestore
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        // user baru, create user document
        await _firestore.collection('users').doc(uid).set({
          'name': googleUser.displayName ?? 'user',
          'email': googleUser.email,
          'role': 'customer',
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      // ambil role dari user document
      final data = userDoc.data() ?? {'role': 'customer'};
      final role = (data['role'] as String?) ?? 'customer';

      return {
        'success': true,
        'role': role,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'google sign in gagal: $e',
      };
    }
  }

  // =====================================================
  // METHOD: Update Profile
  // =====================================================
  Future<Map<String, dynamic>> updateProfile({
    required String uid,
    String? newName,
    String? newEmail,
  }) async {
    // penjelasan:
    // - update user profile (name dan/atau email)
    // - update di firebase auth & firestore
    // - jika email berubah, send verification email

    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'user tidak login',
        };
      }

      // update nama di firebase auth
      if (newName != null && newName.isNotEmpty) {
        await user.updateDisplayName(newName);
      }

      // update email di firebase auth
      if (newEmail != null && newEmail.isNotEmpty && newEmail != user.email) {
        await user.updateEmail(newEmail);
        // send verification email
        await user.sendEmailVerification();
      }

      // update di firestore
      final updateData = <String, dynamic>{};
      if (newName != null && newName.isNotEmpty) {
        updateData['name'] = newName;
      }
      if (newEmail != null && newEmail.isNotEmpty) {
        updateData['email'] = newEmail;
      }

      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updateData);
      }

      return {
        'success': true,
        'message': 'profile updated successfully',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'gagal update profile',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'error: $e',
      };
    }
  }

  // =====================================================
  // METHOD: Get User By ID
  // =====================================================
  Future<UserData?> getUserById(String uid) async {
    // penjelasan:
    // - fetch user data dari firestore
    // - convert ke UserData object
    // - return null jika user tidak ada

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserData.fromFirestore(doc);
    } catch (e) {
      debugPrint("error getting user: $e");
      return null;
    }
  }

  // =====================================================
  // METHOD: Sign Out
  // =====================================================
  Future<void> signOut() async {
    // penjelasan:
    // - logout dari firebase auth & google

    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
    } catch (e) {
      debugPrint("error signing out: $e");
    }
  }
}
```

---

## 2. queue_service.dart

### Deskripsi
QueueService menangani booking queue operations (create, update, delete booking).

### Key Methods

```dart
class QueueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, int> _serviceDurationCache = {};
  // cache untuk service duration agar tidak perlu query berulang kali

  // =====================================================
  // STREAM: Active Queue
  // =====================================================
  Stream<List<Queue>> getActiveQueueStream(String barbershopId) {
    // penjelasan:
    // - listen real-time pada booking aktif (booked, ongoing)
    // - return stream of queue list
    // - auto-update setiap ada perubahan di firestore

    return _firestore
        .collection('queues')
        .where('barbershop_id', isEqualTo: barbershopId)
        .where('status', whereIn: ['booked', 'ongoing'])
        .orderBy('booking_time', descending: false)
        .withConverter<Queue>(
          fromFirestore: (snap, _) => Queue.fromFirestore(snap),
          toFirestore: (queue, _) => queue.toJson(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // =====================================================
  // STREAM: Queue for Customer
  // =====================================================
  Stream<List<Queue>> streamQueuesForCustomer(
    String customerId, {
    List<String>? statusFilter,
  }) {
    // penjelasan:
    // - listen pada queue milik customer tertentu
    // - bisa filter by status (optional)
    // - return stream of queue list

    Query<Map<String, dynamic>> query = _firestore
        .collection('queues')
        .where('customer_id', isEqualTo: customerId);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', whereIn: statusFilter);
    }

    query = query.orderBy('booking_time', descending: true);

    return query
        .withConverter<Queue>(
          fromFirestore: (snap, _) => Queue.fromFirestore(snap),
          toFirestore: (queue, _) => queue.toJson(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  }

  // =====================================================
  // ACTION: Start Service
  // =====================================================
  Future<void> startService(String queueId) async {
    // penjelasan:
    // - change status dari 'booked' → 'ongoing'
    // - set start_time ke current time
    // - update updated_at timestamp

    try {
      await _firestore.collection('queues').doc(queueId).update({
        'start_time': FieldValue.serverTimestamp(),
        'status': 'ongoing',
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("error starting service for queue $queueId: $e");
      rethrow;
    }
  }

  // =====================================================
  // ACTION: Finish Service
  // =====================================================
  Future<void> finishService(String queueId) async {
    // penjelasan:
    // - change status dari 'ongoing' → 'served'
    // - set finish_time ke current time
    // - update updated_at timestamp

    try {
      await _firestore.collection('queues').doc(queueId).update({
        'finish_time': FieldValue.serverTimestamp(),
        'status': 'served',
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("error finishing service for queue $queueId: $e");
      rethrow;
    }
  }

  // =====================================================
  // ACTION: Cancel Queue
  // =====================================================
  Future<void> cancelQueue(String queueId) async {
    // penjelasan:
    // - change status ke 'cancelled'
    // - set cancelled_at timestamp
    // - update updated_at timestamp

    try {
      await _firestore.collection('queues').doc(queueId).update({
        'status': 'cancelled',
        'cancelled_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("error cancelling queue $queueId: $e");
      rethrow;
    }
  }

  // =====================================================
  // ACTION: Create Queue
  // =====================================================
  Future<String> createQueue(Queue queue) async {
    // penjelasan:
    // - create queue baru di firestore
    // - return document id dari queue yang dibuat

    try {
      final docRef = await _firestore
          .collection('queues')
          .add(queue.toJson());
      return docRef.id;
    } catch (e) {
      debugPrint("error creating queue: $e");
      rethrow;
    }
  }

  // =====================================================
  // HELPER: Get Queue By ID
  // =====================================================
  Future<Queue?> getQueueById(String queueId) async {
    // penjelasan:
    // - fetch satu queue dari firestore
    // - convert ke Queue object
    // - return null jika tidak ada

    try {
      final doc = await _firestore.collection('queues').doc(queueId).get();
      if (!doc.exists) return null;
      return Queue.fromFirestore(doc);
    } catch (e) {
      debugPrint("error getting queue: $e");
      return null;
    }
  }
}
```

---

## 3. barbershop_service.dart & barberman_service.dart

### Deskripsi
BarbershopService & BarbermanService menangani data barbershop dan barber (fetch, search, filter).

### Key Methods (BarbershopService)

```dart
class BarbershopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =====================================================
  // FUTURE: Get All Barbershops
  // =====================================================
  Future<List<Barbershop>> getAllBarbershops() async {
    // penjelasan:
    // - fetch semua barbershop dari firestore
    // - return list of barbershop
    // - digunakan di home screen untuk tampilkan barbershop list

    try {
      final snapshot = await _firestore.collection('barbershops').get();
      return snapshot.docs
          .map((doc) => Barbershop.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint("error getting barbershops: $e");
      return [];
    }
  }

  // =====================================================
  // FUTURE: Get Barbershop By ID
  // =====================================================
  Future<Barbershop?> getBarbershopById(String id) async {
    // penjelasan:
    // - fetch satu barbershop dari firestore
    // - return null jika tidak ada

    try {
      final doc = await _firestore.collection('barbershops').doc(id).get();
      if (!doc.exists) return null;
      return Barbershop.fromFirestore(doc);
    } catch (e) {
      debugPrint("error getting barbershop: $e");
      return null;
    }
  }

  // =====================================================
  // FUTURE: Get Services
  // =====================================================
  Future<List<Service>> getAllServices() async {
    // penjelasan:
    // - fetch semua service dari firestore
    // - return list of service
    // - digunakan di appointment screen untuk tampilkan service options

    try {
      final snapshot = await _firestore.collection('services').get();
      return snapshot.docs
          .map((doc) => Service.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint("error getting services: $e");
      return [];
    }
  }

  // =====================================================
  // FUTURE: Get Barbermen By Shop
  // =====================================================
  Future<List<Barberman>> getBarbermenByShop(String barbershopId) async {
    // penjelasan:
    // - fetch semua barberman yang bekerja di barbershop tertentu
    // - filter by barbershop_id & isActive
    // - return list of barberman

    try {
      final snapshot = await _firestore
          .collection('barbermen')
          .where('barbershop_id', isEqualTo: barbershopId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => Barberman.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint("error getting barbermen: $e");
      return [];
    }
  }

  // =====================================================
  // FUTURE: Get Barberman By ID
  // =====================================================
  Future<Barberman?> getBarbermanById(String id) async {
    // penjelasan:
    // - fetch satu barberman dari firestore
    // - return null jika tidak ada

    try {
      final doc = await _firestore.collection('barbermen').doc(id).get();
      if (!doc.exists) return null;
      return Barberman.fromFirestore(doc);
    } catch (e) {
      debugPrint("error getting barberman: $e");
      return null;
    }
  }
}
```

---

## WIDGETS LAYER

### Deskripsi Umum
Widgets folder berisi reusable UI components:
1. **LoadingWidget** - Loading spinner
2. **QueueCard** - Card widget untuk display queue

---

## 1. loading_widget.dart

### Deskripsi
LoadingWidget adalah simple reusable widget untuk tampilkan loading spinner.

### Struktur Code

```dart
import 'package:flutter/material.dart';

const Color kBrownAccent = Color(0xFFC3A47B);

class LoadingWidget extends StatelessWidget {
  final Color color;  // customizable color (default kBrownAccent)

  const LoadingWidget({
    super.key,
    this.color = kBrownAccent,
  });

  @override
  Widget build(BuildContext context) {
    // penjelasan:
    // - stateless widget (tidak ada state)
    // - return center dengan circular progress indicator
    // - color parameter bisa di-customize saat digunakan

    return Center(
      child: CircularProgressIndicator(color: color),
    );
  }
}

// =====================================================
// USAGE EXAMPLE
// =====================================================
// di code:
// LoadingWidget() → default warna kBrownAccent
// LoadingWidget(color: Colors.white) → warna putih
// LoadingWidget(color: Colors.red) → warna merah
```

### Digunakan Di
- Setiap screen yang punya async operations (FutureBuilder, StreamBuilder)
- LoadingWidget() untuk show default loading spinner

---

## 2. queue_card.dart

### Deskripsi
QueueCard adalah widget untuk display satu queue/booking di admin live queue screen. Tampilkan detail booking + action buttons (start, finish, cancel).

### Features
- Display queue details (customer, barberman, service, time)
- Status badge dengan warna berbeda
- Action buttons (start, finish, cancel, confirm)
- FutureBuilder untuk fetch customer & barberman info
- Loading & error handling

### Struktur Code

```dart
class QueueCard extends StatefulWidget {
  final Queue queue;
  // queue object yang di-display

  final FutureOr<void> Function()? onStartService;
  final FutureOr<void> Function()? onFinishService;
  final FutureOr<void> Function()? onCancelQueue;
  final FutureOr<void> Function()? onConfirmBooking;
  // penjelasan:
  // - optional callbacks untuk handle action button presses
  // - FutureOr: bisa return void atau Future<void>
  // - digunakan untuk async operations (update firestore)

  const QueueCard({
    super.key,
    required this.queue,
    this.onStartService,
    this.onFinishService,
    this.onCancelQueue,
    this.onConfirmBooking,
  });

  @override
  State<QueueCard> createState() => _QueueCardState();
}

// =====================================================
// STATE CLASS
// =====================================================
class _QueueCardState extends State<QueueCard> {
  final AuthService _authService = AuthService();
  final BarbershopService _barbershopService = BarbershopService();

  // =====================================================
  // FUTURES untuk fetch detail
  // =====================================================
  late Future<UserData?> _customerFuture;
  late Future<Barberman?> _barbermanFuture;
  // penjelasan:
  // - futures untuk fetch customer & barberman info
  // - di-initialize di initState
  // - di-update di didUpdateWidget jika queue berubah

  // =====================================================
  // LOADING FLAGS
  // =====================================================
  bool _processingStart = false;
  bool _processingFinish = false;
  bool _processingCancel = false;
  bool _processingConfirm = false;
  // penjelasan:
  // - flags untuk track loading state untuk setiap action
  // - prevent double-tap saat loading
  // - disable button saat true

  @override
  void initState() {
    super.initState();
    _initFutures();
  }

  @override
  void didUpdateWidget(covariant QueueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // re-initialize futures jika queue berubah
    if (oldWidget.queue.id != widget.queue.id) {
      _initFutures();
    }
  }

  void _initFutures() {
    // penjelasan:
    // - fetch customer & barberman info
    // - digunakan untuk display nama dan info di card

    _customerFuture = _authService.getUserById(widget.queue.customerId);
    _barbermanFuture = _barbershop_service_getBarbermanSafe(
      widget.queue.barbermanId,
    );
  }

  // =====================================================
  // HELPER: Safe Barberman Fetch
  // =====================================================
  Future<Barberman?> _barbershop_service_getBarbermanSafe(String id) {
    // penjelasan:
    // - wrapper untuk avoid error jika id kosong
    // - return null jika id empty, tanpa throw exception

    if (id.isEmpty) return Future.value(null);
    return _barbershopService.getBarbermanById(id);
  }

  // =====================================================
  // HELPER: Format Status Label
  // =====================================================
  String _statusToLabel(QueueStatus s) {
    // penjelasan:
    // - convert enum status ke display label (bahasa indonesia)

    switch (s) {
      case QueueStatus.waiting:
        return 'menunggu konfirmasi';
      case QueueStatus.booked:
        return 'terkonfirmasi';
      case QueueStatus.ongoing:
        return 'sedang dicukur';
      case QueueStatus.served:
        return 'selesai';
      case QueueStatus.cancelled:
        return 'dibatalkan';
    }
  }

  // =====================================================
  // HELPER: Get Status Color
  // =====================================================
  Color _getStatusColor(QueueStatus status) {
    // penjelasan:
    // - return warna berdasarkan status
    // - untuk display status badge

    switch (status) {
      case QueueStatus.waiting:
        return Colors.orange;
      case QueueStatus.booked:
        return Colors.blue;
      case QueueStatus.ongoing:
        return Colors.purple;
      case QueueStatus.served:
        return Colors.green;
      case QueueStatus.cancelled:
        return Colors.red;
    }
  }

  // =====================================================
  // ACTION HANDLERS
  // =====================================================
  void _handleStartService() async {
    setState(() => _processingStart = true);
    try {
      await widget.onStartService?.call();
    } catch (e) {
      debugPrint("error starting service: $e");
    } finally {
      if (mounted) setState(() => _processingStart = false);
    }
  }

  void _handleFinishService() async {
    setState(() => _processingFinish = true);
    try {
      await widget.onFinishService?.call();
    } catch (e) {
      debugPrint("error finishing service: $e");
    } finally {
      if (mounted) setState(() => _processingFinish = false);
    }
  }

  void _handleCancelQueue() async {
    setState(() => _processingCancel = true);
    try {
      await widget.onCancelQueue?.call();
    } catch (e) {
      debugPrint("error cancelling queue: $e");
    } finally {
      if (mounted) setState(() => _processingCancel = false);
    }
  }
```

### UI: Build Card

```dart
  @override
  Widget build(BuildContext context) {
    final status = widget.queue.status;
    final statusLabel = _statusToLabel(status);
    final statusColor = _getStatusColor(status);

    // penjelasan build method:
    // - return card dengan queue details
    // - gunakan FutureBuilder untuk fetch customer & barberman
    // - tampilkan action buttons sesuai status

    return Card(
      color: kDarkSurface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =====================================================
            // STATUS BADGE
            // =====================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // =====================================================
            // CUSTOMER INFO (fetch dengan FutureBuilder)
            // =====================================================
            FutureBuilder<UserData?>(
              future: _customerFuture,
              builder: (context, snapshot) {
                String customerName = 'loading...';
                if (snapshot.hasData && snapshot.data != null) {
                  customerName = snapshot.data!.name;
                }
                return Text(
                  'customer: $customerName',
                  style: const TextStyle(color: Colors.white),
                );
              },
            ),

            // =====================================================
            // BARBERMAN INFO (fetch dengan FutureBuilder)
            // =====================================================
            FutureBuilder<Barberman?>(
              future: _barbermanFuture,
              builder: (context, snapshot) {
                String barbermanName = 'loading...';
                if (snapshot.hasData && snapshot.data != null) {
                  barbermanName = snapshot.data!.name;
                }
                return Text(
                  'barberman: $barbermanName',
                  style: const TextStyle(color: Colors.white70),
                );
              },
            ),

            const SizedBox(height: 12),

            // =====================================================
            // ACTION BUTTONS (berdasarkan status)
            // =====================================================
            Wrap(
              spacing: 8,
              children: [
                // tombol confirm (hanya untuk status waiting)
                if (status == QueueStatus.waiting)
                  ElevatedButton(
                    onPressed: _processingConfirm
                        ? null
                        : _handleStartService,  // atau onConfirmBooking
                    child: _processingConfirm
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(),
                          )
                        : const Text('confirm'),
                  ),

                // tombol start (hanya untuk status booked)
                if (status == QueueStatus.booked)
                  ElevatedButton(
                    onPressed: _processingStart ? null : _handleStartService,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: _processingStart
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(),
                          )
                        : const Text('start'),
                  ),

                // tombol finish (hanya untuk status ongoing)
                if (status == QueueStatus.ongoing)
                  ElevatedButton(
                    onPressed: _processingFinish ? null : _handleFinishService,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: _processingFinish
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(),
                          )
                        : const Text('finish'),
                  ),

                // tombol cancel (untuk semua status kecuali served/cancelled)
                if (status != QueueStatus.served && status != QueueStatus.cancelled)
                  ElevatedButton(
                    onPressed: _processingCancel ? null : _handleCancelQueue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: _processingCancel
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(),
                          )
                        : const Text('cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// USAGE EXAMPLE
// =====================================================
// di live queue screen:
// QueueCard(
//   queue: queue,
//   onStartService: () async {
//     await queueService.startService(queue.id);
//   },
//   onFinishService: () async {
//     await queueService.finishService(queue.id);
//   },
//   onCancelQueue: () async {
//     await queueService.cancelQueue(queue.id);
//   },
// )
```

---

## Summary

### Service Methods
| Service | Method | Purpose |
|---------|--------|---------|
| AuthService | signIn() | Login dengan email/password |
| AuthService | registerCustomer() | Register user baru |
| AuthService | signInWithGoogle() | Login dengan google |
| AuthService | updateProfile() | Update user profile |
| QueueService | streamQueuesForCustomer() | Real-time booking list untuk customer |
| QueueService | startService() | Change status booked → ongoing |
| QueueService | finishService() | Change status ongoing → served |
| BarbershopService | getAllBarbershops() | Fetch semua barbershop |
| BarbershopService | getBarbermenByShop() | Fetch barber di barbershop tertentu |

### Widgets Usage
```dart
// LoadingWidget
LoadingWidget()  // show default spinner (brown)
LoadingWidget(color: Colors.white)  // customize color

// QueueCard
QueueCard(
  queue: queue,
  onStartService: () async { ... },
  onFinishService: () async { ... },
  onCancelQueue: () async { ... },
)
```

### Best Practices
1. **Always use try-catch** di service methods
2. **Use debugPrint** untuk logging (tidak print ke production)
3. **Use FutureOr** untuk callback yang bisa sync atau async
4. **Cache data** jika frequently accessed (seperti duration cache)
5. **Use withConverter** di firestore queries untuk auto mapping
6. **Check mounted** setelah async operations sebelum setState
7. **Disable buttons saat loading** dengan boolean flags
8. **Handle null values** gracefully di UI

