import 'package:cloud_firestore/cloud_firestore.dart';

// penjelasan class barbershop:
// - class ini mewakili satu barbershop (toko potong rambut)
// - menyimpan informasi: nama, alamat, rating, jam buka, dll
// - final berarti property tidak bisa diubah setelah object dibuat
class Barbershop {
  // penjelasan property:
  final String id; // id unik dari database (firebase)
  final String name; // nama barbershop (contoh: "Barber Premium")
  final String
  addres; // alamat (CATATAN: field ini sengaja typo 'addres' seperti di database)
  final double rating; // rating barbershop (0.0 - 5.0)
  final String imageUrl; // url gambar barbershop (dari internet)
  final List<String>
  services; // list berisi id service yang ada di barbershop ini
  final int openHour; // jam buka toko (format 0-23, contoh: 9 = jam 9 pagi)
  final int closeHour; // jam tutup toko (format 0-23, contoh: 21 = jam 9 malam)
  final int?
  paymentWindowMinutes; // payment window in minutes for awaiting_payment (optional)
  final bool isOpen; // status apakah toko sedang buka sekarang

  // penjelasan constructor:
  // - semua parameter adalah required (harus diberikan)
  // - ini memastikan setiap barbershop selalu memiliki informasi lengkap
  Barbershop({
    required this.id,
    required this.name,
    required this.addres,
    required this.rating,
    required this.imageUrl,
    required this.services,
    required this.openHour,
    required this.closeHour,
    this.paymentWindowMinutes,
    required this.isOpen,
  });

  // penjelasan factory barbershop.fromfirestore:
  // - factory adalah constructor khusus untuk membuat object dari data firebase
  // - DocumentSnapshot<Map<String, dynamic>> = data yang diambil dari firebase
  // - doc.data() ?? {} = ambil data, jika null gunakan map kosong {}
  // - doc.id = id dokumen di firebase (digunakan sebagai barbershop id)
  // - method ini memastikan data dari firebase bisa dikonversi jadi object barbershop
  factory Barbershop.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    // penjelasan helper function parsehour:
    // - helper function adalah function kecil untuk handle case tertentu
    // - parsehour mengubah open_hour/close_hour dari berbagai format menjadi int
    // - bisa input: int (9), string ("09"), string dengan format ("09:00")
    // - fallback = nilai default jika parsing gagal
    // contoh:
    // - parseHour(9, 9) = 9
    // - parseHour("09", 9) = 9
    // - parseHour("09:00", 9) = 9
    // - parseHour(null, 9) = 9
    int parseHour(dynamic value, int fallback) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is String) {
        // jika string berisi ':', ambil bagian sebelum ':'
        // contoh: "09:00" menjadi "09", kemudian di-parse jadi int 9
        if (value.contains(':')) {
          return int.tryParse(value.split(':').first) ?? fallback;
        }
        // jika tidak ada ':', parse langsung ke int
        return int.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    // penjelasan addressValue:
    // - data['address'] = coba cari field 'address' (benar)
    // - ?? data['addres'] = jika tidak ada, coba 'addres' (salah di database)
    // - ?? 'Alamat Tidak Diketahui' = jika keduanya tidak ada, gunakan text default
    // - as String = cast hasilnya jadi string
    // - ini memastikan compatibility dengan berbagai format database
    final String addressValue =
        (data['address'] ?? data['addres'] ?? 'Alamat Tidak Diketahui')
            as String;

    // buat barbershop object dari data firebase
    return Barbershop(
      id: doc.id,
      name: data['name'] ?? 'Nama Barbershop',
      addres: addressValue,
      // rating: ambil dari database dan convert ke double, jika tidak ada default 5.0
      // as num? = cast ke number (bisa int atau double), toDouble() = ubah ke double
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      imageUrl:
          data['imageUrl'] ??
          'https://cdn-icons-png.flaticon.com/512/706/706830.png',
      // services: ambil dari database, jika itu list maka convert ke List<String>
      // jika bukan list, gunakan list kosong []
      services: (data['services'] is List)
          ? List<String>.from(data['services'])
          : <String>[],
      // gunakan parseHour helper untuk handle berbagai format
      // default jam buka 9 pagi jika tidak ada di database
      openHour: parseHour(data['open_hour'] ?? data['openHour'], 9),
      // default jam tutup 21 (9 malam) jika tidak ada di database
      closeHour: parseHour(data['close_hour'] ?? data['closeHour'], 21),
      // paymentWindowMinutes: optional per-shop configuration
      paymentWindowMinutes:
          (data['payment_window_minutes'] as num?)?.toInt() ??
          (data['paymentWindowMinutes'] as num?)?.toInt(),
      // isOpen: ambil dari database, default false jika tidak ada
      isOpen: data['isOpen'] as bool? ?? false,
    );
  }

  // penjelasan method tojson:
  // - method ini mengubah object Barbershop menjadi Map (dictionary)
  // - digunakan saat menyimpan ke firebase
  // - return hasilnya adalah Map<String, dynamic> (key = string, value = tipe apa saja)
  // - ini cara umum untuk mempersiapkan data sebelum disimpan ke database
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'addres': addres, // menggunakan 'addres' seperti di database
      'rating': rating,
      'imageUrl': imageUrl,
      'services': services,
      'open_hour': openHour,
      'close_hour': closeHour,
      'payment_window_minutes': paymentWindowMinutes,
      'isOpen': isOpen,
    };
  }
}
