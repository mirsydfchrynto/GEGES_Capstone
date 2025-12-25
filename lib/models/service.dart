import 'package:cloud_firestore/cloud_firestore.dart';

// penjelasan class service:
// - class ini mewakili satu jenis layanan potong/styling
// - menyimpan info: nama, harga, durasi estimasi, dll
// - final property berarti tidak bisa diubah setelah object dibuat
class Service {
  // penjelasan property:
  final String id; // id unik dari firebase
  final String name; // nama layanan (contoh: "potong rambut panjang")
  final String description; // deskripsi detail layanan
  final double price; // harga layanan (Rp)
  final int defaultDuration; // durasi estimasi (menit, contoh: 30)
  final bool isActive; // apakah service masih aktif/bisa dipesan

  // penjelasan constructor:
  // - semua parameter required = harus diberikan
  Service({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.defaultDuration,
    required this.isActive,
  });

  // penjelasan factory service.fromfirestore:
  // - factory constructor untuk create object dari firebase data
  // - DocumentSnapshot adalah response dari firebase query
  // - doc.data() ?? {} = ambil data, jika null gunakan map kosong
  // - penting untuk handle berbagai format field name (snake_case vs camelCase)
  factory Service.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    // helper: convert duration dari firebase (bisa int atau num)
    // coba field 'default_duration' dulu, jika tidak ada coba 'defaultDuration'
    // jika keduanya tidak ada, gunakan default 30 menit
    final duration =
        (data['default_duration'] as num?)?.toInt() ??
        (data['defaultDuration'] as num?)?.toInt() ??
        30;

    // helper: convert price ke double
    // default 0.0 jika tidak ada
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;

    // helper: isactive default true jika tidak ada
    final isActive = data['isActive'] as bool? ?? true;

    return Service(
      id: doc.id, // id dari firebase dokumen
      name: data['name'] as String? ?? 'Service Unknown',
      description:
          data['description'] as String? ??
          '', // jika tidak ada, gunakan empty string
      price: price,
      defaultDuration: duration,
      isActive: isActive,
    );
  }

  // penjelasan method tojson:
  // - convert object service menjadi map untuk disimpan ke firebase
  // - digunakan saat create/update service di database
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'default_duration': defaultDuration,
      'isActive': isActive,
    };
  }
}
