# DOKUMENTASI CUSTOMER SCREENS - APPOINTMENT, PAYMENT, EDIT PROFILE

## Pengantar
Ketiga screens ini adalah core screens untuk customer booking flow:
1. **AppointmentScreen** - Pilih barberman, service, tanggal, jam
2. **PaymentScreen** - Upload bukti pembayaran (manual payment)
3. **EditProfileScreen** - Edit nama dan email user

---

## 1. appointment_screen.dart

### Deskripsi
AppointmentScreen adalah halaman untuk customer memilih detail booking:
- Pilih service (barbershop sudah di-select sebelumnya)
- Pilih barberman
- Pilih tanggal & jam
- Lihat harga total, durasi, waktu selesai
- Cek ketersediaan slot
- Konfirm dan lanjut ke payment

### Features
- FutureBuilder untuk load services & barbermen
- Multi-select services (bisa pilih lebih dari 1 layanan)
- Barberman selection
- Date & time picker
- Real-time price & duration calculation
- Slot availability checking
- Total price display
- Navigasi ke PaymentScreen

### Key Components

```dart
// =====================================================
// INPUT: BARBERSHOP (dari previous screen)
// =====================================================
class AppointmentScreen extends StatefulWidget {
  final Barbershop barbershop;  // barbershop yang di-select sebelumnya
  
  const AppointmentScreen({
    super.key,
    required this.barbershop,
  });

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

// =====================================================
// STATE PROPERTIES
// =====================================================
class _AppointmentScreenState extends State<AppointmentScreen> {
  // =====================================================
  // SERVICES & BARBERMEN
  // =====================================================
  final List<Service> _selectedServices = [];
  // penjelasan:
  // - list untuk track service mana yang di-pilih user
  // - user bisa pilih lebih dari 1 service
  // - digunakan untuk hitung total price & duration

  Barberman? _selectedBarberman;
  // penjelasan:
  // - barberman yang di-select user
  // - digunakan untuk cek ketersediaan & estimasi waktu
  // - penting untuk validasi (tidak boleh null sebelum booking)

  // =====================================================
  // DATE & TIME
  // =====================================================
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  // penjelasan:
  // - _selectedDate = tanggal booking
  // - _selectedTime = jam booking
  // - keduanya di-initialize di initState dengan current time + 15min

  DateTime? _estimatedFinishTime;
  // penjelasan:
  // - waktu estimated selesai booking
  // - hitung dari: selected time + total duration
  // - di-update setiap ada perubahan service atau barberman

  // =====================================================
  // VALIDATION & AVAILABILITY
  // =====================================================
  bool _isSlotAvailable = false;
  // penjelasan:
  // - flag untuk track apakah slot tersedia
  // - di-check via _checkSlotAvailability() async
  // - jika false, user tidak bisa confirm booking

  String _slotAvailabilityMessage = '';
  // penjelasan:
  // - pesan untuk tampilkan status ketersediaan slot
  // - contoh: "slot tersedia" atau "slot tidak tersedia"
```

### Key Method: _updateEstimatedFinishTime()

```dart
void _updateEstimatedFinishTime() {
  // penjelasan:
  // - hitung waktu selesai berdasarkan selected time + total duration
  // - dipanggil setiap ada perubahan service atau barberman
  // - setelah update, langsung check slot availability

  if (_selectedBarberman != null && _selectedServices.isNotEmpty) {
    // hanya hitung jika barberman dan service sudah dipilih

    // step 1: buat datetime object dari selected date & time
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // step 2: ambil total durasi dari semua selected services
    final minutes = _totalDuration;

    // step 3: hitung estimated finish time
    setState(() {
      _estimatedFinishTime = start.add(Duration(minutes: minutes));
    });

    // step 4: check apakah slot tersedia
    _checkSlotAvailability();
  } else {
    // reset jika barberman atau service belum dipilih
    setState(() {
      _estimatedFinishTime = null;
      _slotAvailabilityMessage = '';
      _isSlotAvailable = false;
    });
  }
}
```

### Getter: Total Price & Duration

```dart
// penjelasan:
// - getters untuk calculate total dari selected services
// - digunakan di UI untuk tampilkan total price dan durasi

int get _totalPrice => _selectedServices.fold(0, (acc, e) => acc + e.price.toInt());
// method:
// - fold() = iterate semua services dan accumulate nilai
// - (acc, e) => acc + e.price.toInt()
//   - acc = accumulator (total saat ini)
//   - e = current element (service)
//   - toInt() convert double ke int untuk harga

int get _totalDuration => _selectedServices.fold(0, (acc, e) => acc + e.defaultDuration);
// sama seperti total price, tapi untuk duration
```

### Key Method: _checkSlotAvailability()

```dart
Future<void> _checkSlotAvailability() async {
  // penjelasan:
  // - check apakah barberman tersedia pada tanggal & jam yang dipilih
  // - query firestore untuk lihat booking yang conflict
  // - update _isSlotAvailable & _slotAvailabilityMessage

  if (_selectedBarberman == null || _selectedServices.isEmpty) return;

  setState(() => _slotAvailabilityMessage = 'mengecek ketersediaan slot...');

  final booking = DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
  );

  try {
    // query firestore untuk cek booking yang overlap
    final conflictingBookings = await FirebaseFirestore.instance
        .collection('queues')
        .where('barberman_id', isEqualTo: _selectedBarberman!.id)
        .where('booking_time', isGreaterThanOrEqualTo: booking)
        .where('booking_time', isLessThan: booking.add(const Duration(days: 1)))
        .where('status', whereIn: ['booked', 'ongoing'])
        .get();

    // penjelasan logic:
    // - ambil semua booking untuk barberman pada hari yang dipilih
    // - filter status 'booked' dan 'ongoing' (booking yang active)
    // - canceled booking tidak dihitung (slot sudah free)

    // step 2: cek apakah ada conflict dengan selected time
    bool slotAvailable = true;
    for (final doc in conflictingBookings.docs) {
      final existingQueue = Queue.fromFirestore(doc);
      final existingStart = existingQueue.bookingTime.toDate();
      final existingEnd = existingStart.add(
        Duration(minutes: existingQueue.estimatedDuration ?? 30),
      );

      final requestedStart = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final requestedEnd = requestedStart.add(
        Duration(minutes: _totalDuration),
      );

      // cek overlap antara existing dan requested time
      // penjelasan:
      // - overlap terjadi jika: requestedStart < existingEnd AND requestedEnd > existingStart
      if (requestedStart.isBefore(existingEnd) && requestedEnd.isAfter(existingStart)) {
        slotAvailable = false;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _isSlotAvailable = slotAvailable;
        _slotAvailabilityMessage = slotAvailable
            ? 'slot tersedia ✓'
            : 'slot tidak tersedia pada jam ini';
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isSlotAvailable = false;
        _slotAvailabilityMessage = 'error checking availability: $e';
      });
    }
  }
}
```

### Key Method: _confirmBooking()

```dart
void _confirmBooking() async {
  // penjelasan:
  // - validate sebelum create booking
  // - create Queue object
  // - navigasi ke PaymentScreen

  // step 1: validate selection
  if (_selectedBarberman == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('pilih barberman terlebih dahulu')),
    );
    return;
  }

  if (_selectedServices.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('pilih minimal 1 service')),
    );
    return;
  }

  if (!_isSlotAvailable) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('slot tidak tersedia, pilih jam lain')),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    // step 2: create queue object
    final bookingDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final queue = Queue(
      id: '', // akan di-generate oleh firestore
      customerId: FirebaseAuth.instance.currentUser!.uid,
      barbershopId: widget.barbershop.id,
      barbermanId: _selectedBarberman!.id,
      serviceIds: _selectedServices.map((e) => e.id).toList(),
      bookingTime: Timestamp.fromDate(bookingDateTime),
      status: QueueStatus.waiting,
      totalPrice: _totalPrice,
      estimatedDuration: _totalDuration,
    );

    // step 3: save ke firestore & get document id
    final docRef = await FirebaseFirestore.instance
        .collection('queues')
        .add(queue.toJson());

    // step 4: navigate ke payment screen
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            orderId: docRef.id,
            totalPrice: _totalPrice,
            barbershopId: widget.barbershop.id,
            barbermanId: _selectedBarberman!.id,
            bookingTime: bookingDateTime,
            serviceIds: _selectedServices.map((e) => e.id).toList(),
          ),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error creating booking: $e')),
      );
    }
  }
}
```

---

## 2. payment_screen.dart

### Deskripsi
PaymentScreen adalah halaman untuk customer menyelesaikan pembayaran dengan upload bukti pembayaran. Aplikasi ini menggunakan manual payment (bukan payment gateway seperti Stripe).

### Features
- Display order details (harga, service, barberman, jam)
- Countdown timer (9:59 → 0:00)
- Image picker (ambil foto dari camera atau gallery)
- Upload bukti pembayaran ke Firebase Storage
- Validasi image sebelum upload
- Show loading state saat upload
- Display base64 image preview

### Key Components

```dart
// =====================================================
// INPUT: PAYMENT DETAILS
// =====================================================
class PaymentScreen extends StatefulWidget {
  final String orderId;              // unique order id
  final int totalPrice;               // total harga
  final String? barbershopId;        // optional
  final String? barbermanId;         // optional
  final DateTime? bookingTime;       // optional
  final List<String>? serviceIds;    // optional

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.totalPrice,
    this.barbershopId,
    this.barbermanId,
    this.bookingTime,
    this.serviceIds,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

// =====================================================
// STATE PROPERTIES
// =====================================================
class _PaymentScreenState extends State<PaymentScreen> {
  // =====================================================
  // TIMER (countdown 9:59 → 0:00)
  // =====================================================
  Timer? _timer;
  Duration _timeRemaining = const Duration(minutes: 9, seconds: 59);
  // penjelasan:
  // - countdown timer untuk time limit pembayaran
  // - 10 menit untuk upload bukti pembayaran
  // - setiap 1 detik, decrement _timeRemaining

  // =====================================================
  // IMAGE & UPLOAD STATE
  // =====================================================
  final ImagePicker _picker = ImagePicker();
  // penjelasan:
  // - ImagePicker dari image_picker package
  // - untuk ambil foto dari camera atau gallery

  File? _pickedImage;
  // penjelasan:
  // - file yang dipilih user
  // - null jika user belum pilih image

  String? _pickedBase64;
  // penjelasan:
  // - base64 encoded string dari image
  // - caching ini agar tidak perlu encode ulang setiap rebuild

  bool _isSubmitting = false;
  // penjelasan:
  // - flag untuk track saat upload ke firebase
  // - disable button saat true
```

### Key Method: _startTimer()

```dart
void _startTimer() {
  // penjelasan:
  // - mulai countdown timer dari 9:59
  // - setiap 1 detik, decrement _timeRemaining
  // - jika sudah habis, cancel timer dan show expiry message

  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (_timeRemaining.inSeconds <= 0) {
      // time expired, cancel timer
      timer.cancel();
      if (mounted) setState(() {});
    } else {
      // decrement 1 detik
      if (mounted) {
        setState(() {
          _timeRemaining = _timeRemaining - const Duration(seconds: 1);
        });
      }
    }
  });
}

@override
void dispose() {
  _timer?.cancel();  // cancel timer saat screen di-close
  super.dispose();
}
```

### Key Method: _formatDuration()

```dart
String _formatDuration(Duration d) {
  // penjelasan:
  // - format duration menjadi HH:MM:SS
  // - digunakan untuk display countdown timer

  String twoDigits(int n) => n.toString().padLeft(2, '0');
  // penjelasan:
  // - convert int ke string dan pad dengan '0' kiri jika perlu
  // - contoh: 9 → '09', 30 → '30'

  String minutes = twoDigits(d.inMinutes.remainder(60));
  // remainder(60) = ambil minutes saja (tidak termasuk hours)

  String seconds = twoDigits(d.inSeconds.remainder(60));
  // remainder(60) = ambil seconds saja (tidak termasuk minutes)

  return "00:$minutes:$seconds";  // format HH:MM:SS
}
```

### Key Method: _pickImage()

```dart
Future<void> _pickImage(bool isCamera) async {
  // penjelasan:
  // - pick image dari camera atau gallery
  // - convert ke base64 untuk display preview
  // - isCamera: true = camera, false = gallery

  try {
    // step 1: ambil permission jika camera
    if (isCamera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        // user reject permission
        return;
      }
    }

    // step 2: pick image
    final pickedFile = await _picker.pickImage(
      source: isCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,  // compress image
    );

    if (pickedFile == null) return;

    // step 3: convert ke file
    final file = File(pickedFile.path);

    // step 4: convert ke base64 untuk preview
    final bytes = await file.readAsBytes();
    final base64String = base64.encode(bytes);

    // step 5: update state
    setState(() {
      _pickedImage = file;
      _pickedBase64 = base64String;
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('error picking image: $e')),
    );
  }
}
```

### Key Method: _submitPayment()

```dart
Future<void> _submitPayment() async {
  // penjelasan:
  // - upload bukti pembayaran ke firebase storage
  // - update queue status menjadi 'booked'
  // - navigasi ke confirmation screen

  // step 1: validate image dipilih
  if (_pickedImage == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('pilih bukti pembayaran terlebih dahulu')),
    );
    return;
  }

  setState(() => _isSubmitting = true);

  try {
    // step 2: upload image ke firebase storage
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('payments/${widget.orderId}.jpg');

    await storageRef.putFile(_pickedImage!);

    // step 3: get download url
    final downloadUrl = await storageRef.getDownloadURL();

    // step 4: update queue status & payment info di firestore
    await FirebaseFirestore.instance
        .collection('queues')
        .doc(widget.orderId)
        .update({
          'status': 'booked',  // change from 'waiting' to 'booked'
          'payment_image_url': downloadUrl,
          'payment_submitted_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

    // step 5: navigate ke confirmation screen
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/booking-confirmation');
      // atau:
      // Navigator.of(context).pushReplacement(
      //   MaterialPageRoute(builder: (context) => const BookingConfirmationScreen()),
      // );
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error submitting payment: $e')),
      );
    }
  }
}
```

---

## 3. edit_profile_screen.dart

### Deskripsi
EditProfileScreen adalah halaman untuk customer edit profile (nama dan email). Input field dan save ke Firebase Auth & Firestore.

### Features
- Edit nama user
- Edit email user
- Form validation
- Password confirmation (untuk change email)
- Save ke Firebase Auth & Firestore
- Error handling
- Success message & navigate back

### Key Components

```dart
// =====================================================
// INPUT: CURRENT USER DATA
// =====================================================
class EditProfileScreen extends StatefulWidget {
  final UserData currentUser;  // user data sebelum di-edit

  const EditProfileScreen({
    required this.currentUser,
    super.key,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

// =====================================================
// STATE PROPERTIES
// =====================================================
class _EditProfileScreenState extends State<EditProfileScreen> {
  // =====================================================
  // FORM PROPERTIES
  // =====================================================
  final _formKey = GlobalKey<FormState>();
  // penjelasan:
  // - global key untuk form validation
  // - bisa call _formKey.currentState!.validate() untuk validasi

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  // penjelasan:
  // - controller untuk manage form input
  // - di-initialize di initState dengan current user data

  bool _isLoading = false;
  // penjelasan:
  // - flag untuk track saat save ke firebase
  // - disable button saat true

  // =====================================================
  // SERVICE
  // =====================================================
  final AuthService _authService = AuthService();
  // penjelasan:
  // - instance untuk handle update profile via auth service

  @override
  void initState() {
    super.initState();
    // initialize controller dengan current user data
    _nameController = TextEditingController(text: widget.currentUser.name);
    _emailController = TextEditingController(
      text: _authService.currentUser?.email ?? 'email@example.com',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
```

### Key Method: _askForPassword()

```dart
Future<String?> _askForPassword() async {
  // penjelasan:
  // - show dialog untuk user input password
  // - digunakan untuk confirm email change (security)
  // - return password string atau null jika user cancel

  String password = '';

  return showDialog<String>(
    context: context,
    barrierDismissible: false,  // user harus jawab, tidak bisa tap outside
    builder: (context) {
      return AlertDialog(
        backgroundColor: kDarkGrey,
        title: const Text(
          'konfirmasi password',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          autofocus: true,
          obscureText: true,  // hide password saat ketik
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'masukkan password anda',
          ),
          onChanged: (v) => password = v,  // capture value saat ketik
        ),
        actions: [
          // button cancel
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),  // return null
            child: const Text('batal'),
          ),
          // button confirm
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(password),  // return password
            child: const Text('lanjut'),
          ),
        ],
      );
    },
  );
}
```

### Key Method: _saveProfile()

```dart
Future<void> _saveProfile() async {
  // penjelasan:
  // - validate form
  // - call auth service untuk update profile
  // - jika email berubah, ask password confirmation
  // - update local state atau navigate back

  // step 1: validate form
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  final newName = _nameController.text.trim();
  final newEmail = _emailController.text.trim();
  final oldEmail = _authService.currentUser?.email ?? '';

  try {
    // step 2: call auth service untuk update
    final result = await _authService.updateProfile(
      uid: widget.currentUser.uid,
      newName: newName,
      newEmail: newEmail,
    );

    if (result['success']) {
      // update berhasil
      if (newEmail != oldEmail) {
        // email di-change, show verification dialog
        _showEmailVerificationDialog(newEmail);
      } else {
        // hanya nama di-change, navigate back dengan updated user
        if (mounted) {
          final updatedUser = UserData(
            uid: widget.currentUser.uid,
            name: newName,
            role: widget.currentUser.role,
            phoneNumber: widget.currentUser.phoneNumber,
            barbershopId: widget.currentUser.barbershopId,
          );

          // pop dan return updated user
          Navigator.of(context).pop(updatedUser);
        }
      }
    } else {
      // error saat update
      _showErrorSnackbar(result['message'] ?? 'gagal update profile');
    }
  } catch (e) {
    _showErrorSnackbar('error: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

### Key Method: _showEmailVerificationDialog()

```dart
void _showEmailVerificationDialog(String newEmail) {
  // penjelasan:
  // - show dialog untuk inform user bahwa email verification email sudah dikirim
  // - user harus buka email dan verify sebelum email berubah

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: kDarkGrey,
        title: const Text(
          'verifikasi email',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'email verifikasi sudah dikirim ke $newEmail\nsilakan buka email dan klik link verifikasi',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // close dialog & navigate back
              Navigator.of(context).pop();
              if (mounted) {
                Navigator.of(context).pop();  // pop edit profile screen
              }
            },
            child: const Text('ok'),
          ),
        ],
      );
    },
  );
}
```

---

## Summary

### Booking Flow
```
HomeScreen (select barbershop)
    ↓
AppointmentScreen
    ├─ Select service (multi-select)
    ├─ Select barberman
    ├─ Select date & time
    ├─ Calculate total price & duration
    ├─ Check slot availability
    └─ Confirm booking
        ↓
PaymentScreen
    ├─ Show order summary
    ├─ Countdown timer (10 min)
    ├─ Pick image (camera or gallery)
    └─ Upload bukti pembayaran
        ↓
BookingConfirmationScreen (success)
```

### Edit Profile Flow
```
ProfileScreen
    ↓
Edit Profile button
    ↓
EditProfileScreen
    ├─ Edit nama
    ├─ Edit email
    └─ Save
        ├─ Update Firebase Auth
        ├─ Update Firestore
        └─ Navigate back dengan updated user
```

### Best Practices
1. **Always validate input** sebelum save
2. **Check slot availability** sebelum booking
3. **Use loading state** untuk disable button saat process
4. **Handle exceptions** dengan specific error messages
5. **Confirm password** saat change email (security)
6. **Use FutureBuilder** untuk async operations
7. **Cleanup resources** di dispose method
8. **Check mounted** setelah async operation sebelum setState

