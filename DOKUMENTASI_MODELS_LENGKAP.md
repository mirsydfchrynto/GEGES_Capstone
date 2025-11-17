# DOKUMENTASI MODEL FILES LENGKAP

## Pengantar
File di folder `lib/models/` mengandung data structures (classes) yang merepresentasikan entitas bisnis dalam aplikasi GEGES SmartBarber. Setiap model memiliki factory constructor untuk mengkonversi data dari Firestore ke objek Dart.

---

## 1. booking_details.dart

### Deskripsi
`BookingDetails` adalah model **gabungan/composite** yang merepresentasikan detail lengkap satu booking. Dibuat dengan menggabungkan data dari Queue + Barbershop + Barberman + Service.

### Struktur Code

```dart
// penjelasan:
// - model ini adalah "view model" yang menggabungkan data dari multiple collections
// - digunakan di UI untuk tampilkan informasi booking dengan lengkap
// - tidak di-save ke firestore, hanya dibuat di client-side
// - alasan: lebih mudah mengakses data di UI tanpa perlu query multiple times

class BookingDetails {
  final Queue queue;                    // booking entry dengan id, time, status
  final String barbershopName;          // nama barbershop (dari barbershops collection)
  final String barbermanName;           // nama barber (dari barbermen collection)
  final String serviceName;             // nama layanan (dari services collection)
  final String barbershopImage;         // url gambar barbershop

  BookingDetails({
    required this.queue,
    required this.barbershopName,
    required this.barbermanName,
    required this.serviceName,
    required this.barbershopImage,
  });
}
```

### Cara Membuat Instance

```dart
// step 1: ambil queue dari firestore
final queue = await queueService.getQueueById(queueId);

// step 2: ambil data barbershop dari firestore
final barbershop = await barbershopService.getBarbershopById(queue.barbershopId);

// step 3: ambil data barberman dari firestore
final barberman = await barbershopService.getBarbermanById(queue.barbermanId);

// step 4: ambil data service dari firestore
final service = await barbershopService.getServiceById(queue.firstServiceId);

// step 5: buat instance BookingDetails
final bookingDetails = BookingDetails(
  queue: queue,
  barbershopName: barbershop.name,
  barbermanName: barberman.name,
  serviceName: service.name,
  barbershopImage: barbershop.imageUrl,
);
```

### Digunakan Di
- `my_bookings_screen.dart` - untuk tampilkan detail booking di list
- `payment_screen.dart` - untuk tampilkan ringkasan booking sebelum pembayaran

---

## 2. promo_banner.dart

### Deskripsi
`PromoBanner` merepresentasikan banner promosi yang ditampilkan di carousel di home screen. Data disimpan di Firestore collection `promos`.

### Struktur Code

```dart
// penjelasan:
// - model untuk promo/iklan yang di-carousel di home screen
// - setiap banner bisa active atau inactive (bisa disembunyikan)
// - image url bisa dari cloud storage atau external url
// - subtitle dan title untuk copy text di banner

class PromoBanner {
  final String id;                      // document id dari firestore
  final String title;                   // judul promo (contoh: "Potong Rambut Gratis")
  final String subtitle;                // subtitle (contoh: "Buruan daftar sekarang!")
  final String imageUrl;                // url gambar banner
  final bool isActive;                  // flag untuk active/inactive promo

  PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.isActive,
  });

  // factory constructor dari firestore
  // penjelasan:
  // - convert firestore document ke dart object
  // - jika field kosong, gunakan default value
  // - alasan: data dari firestore bisa incomplete atau null
  factory PromoBanner.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return PromoBanner(
      id: doc.id,
      title: data['title'] as String? ?? 'Promo Spesial',
      subtitle: data['subtitle'] as String? ?? 'Cek sekarang!',
      imageUrl: data['imageUrl'] as String? ?? 'https://placeholder.com/600x400',
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}
```

### Field Penjelasan

| Field | Tipe | Deskripsi |
|-------|------|-----------|
| `id` | String | Document ID dari Firestore |
| `title` | String | Judul promosi |
| `subtitle` | String | Subtitle/deskripsi singkat |
| `imageUrl` | String | URL gambar banner |
| `isActive` | bool | Status aktif/nonaktif |

### Digunakan Di
- `home_screen.dart` - PromoCarousel widget untuk tampilkan carousel
- Firebase Firestore collection: `promos`

### Contoh Data Firestore
```json
{
  "id": "promo_1",
  "title": "Potong Rambut Gratis",
  "subtitle": "Daftar sekarang dan gratis potong!",
  "imageUrl": "https://example.com/promo1.jpg",
  "isActive": true
}
```

---

## 3. user_data.dart

### Deskripsi
`UserData` merepresentasikan data user (customer atau admin_owner) di sistem. Disimpan di Firestore collection `users`.

### Struktur Code

```dart
// penjelasan:
// - model untuk user profile (customer atau admin/owner)
// - setiap user punya role untuk determine permissions
// - barbershopId hanya ada jika user adalah admin_owner (owner barbershop)
// - phoneNumber optional, untuk kontak customer
// - field bisa snake_case (dari db) atau camelCase (dari cache)

class UserData {
  final String uid;                     // firebase auth uid (unique identifier)
  final String name;                    // nama lengkap user
  final String role;                    // 'customer' atau 'admin_owner'
  final String? phoneNumber;            // nomor telepon (optional, nullable)
  final String? barbershopId;           // id barbershop yang dikelola (jika admin_owner)

  UserData({
    required this.uid,
    required this.name,
    required this.role,
    this.phoneNumber,
    this.barbershopId,
  });

  // factory constructor dari firestore
  // penjelasan:
  // - convert firestore document ke dart object
  // - handle field name variations (snake_case vs camelCase)
  // - jika data tidak valid, return default guest user
  factory UserData.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();

    // safety check: pastikan data adalah Map
    // penjelasan: firestore bisa return data dalam berbagai tipe
    if (raw is! Map<String, dynamic>) {
      debugPrint('⚠️ invalid firestore data for user: ${doc.id}');
      return UserData(uid: doc.id, name: 'guest', role: 'customer');
    }

    final data = raw;

    // ambil barbershop id dengan fallback field name
    // penjelasan:
    // - database bisa gunakan snake_case (barbershop_id) atau camelCase (barbershopId)
    // - try yang pertama, jika kosong try yang kedua
    // - jika kedua-duanya kosong, gunakan null
    final shopId = data['barbershop_id'] as String? ?? data['barbershopId'] as String?;

    return UserData(
      uid: doc.id,
      name: data['name'] as String? ?? 'guest',
      role: data['role'] as String? ?? 'customer',
      phoneNumber: data['phone_number'] as String? ?? data['phoneNumber'] as String?,
      barbershopId: shopId,
    );
  }

  // convert ke json untuk upload ke firestore
  // penjelasan:
  // - saat save user ke firestore, gunakan toJson()
  // - gunakan snake_case untuk consistency dengan database
  // - jika field null, bisa memakai `if` condition untuk exclude dari map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (barbershopId != null) 'barbershop_id': barbershopId,
    };
  }
}
```

### Field Penjelasan

| Field | Tipe | Deskripsi |
|-------|------|-----------|
| `uid` | String | Firebase Auth UID (unique) |
| `name` | String | Nama lengkap user |
| `role` | String | 'customer' atau 'admin_owner' |
| `phoneNumber` | String? | Nomor telepon (nullable) |
| `barbershopId` | String? | ID barbershop (hanya untuk admin_owner) |

### Role Explanation

```dart
// 'customer':
// - user biasa yang booking haircut
// - bisa akses home screen, appointment screen, profile
// - tidak bisa akses admin dashboard

// 'admin_owner':
// - pemilik/manager barbershop
// - bisa akses admin dashboard
// - bisa manage live queue, lihat booking, tambah booking manual
// - terikat pada satu barbershop
```

### Digunakan Di
- `login_screen.dart` - saat login, load UserData
- `register_screen.dart` - saat register, buat UserData baru
- `profile_screen.dart` - tampilkan profile user
- `edit_profile_screen.dart` - edit profile user
- `admin_dashboard.dart` - check admin permissions

### Contoh Data Firestore (Customer)
```json
{
  "uid": "user_123",
  "name": "Tegar Nugraha",
  "email": "tegar@example.com",
  "role": "customer",
  "phone_number": "+62812345678",
  "created_at": "2024-01-15"
}
```

### Contoh Data Firestore (Admin/Owner)
```json
{
  "uid": "admin_456",
  "name": "Admin Geges",
  "email": "admin@geges.com",
  "role": "admin_owner",
  "barbershop_id": "barber_789",
  "phone_number": "+62898765432"
}
```

---

## Summary & Best Practices

### Ketiga Model
1. **BookingDetails** - Composite model (client-side only)
2. **PromoBanner** - Promo/advertising model
3. **UserData** - User profile model

### Best Practices
1. **Gunakan factory constructor** untuk convert dari Firestore
2. **Berikan default value** jika field kosong
3. **Handle field name variations** (snake_case vs camelCase)
4. **Dokumentasikan role** dan permissions dengan jelas
5. **Nullable fields** gunakan `?` untuk optional values
6. **toJson()** untuk serialization saat save ke database

### Field Naming Convention
- Firestore: `snake_case` (barbershop_id, phone_number)
- Dart Code: `camelCase` (barbershopId, phoneNumber)
- Factory constructor: handle kedua-duanya untuk flexibility

