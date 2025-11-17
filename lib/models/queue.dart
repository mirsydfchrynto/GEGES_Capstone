import 'package:cloud_firestore/cloud_firestore.dart';

// penjelasan enum queuestatus:
// - enum adalah tipe data yang memiliki beberapa pilihan nilai tetap
// - queuestatus hanya bisa bernilai: waiting, booked, ongoing, served, atau cancelled
// - ini memastikan status booking hanya bisa salah satu dari pilihan tersebut
// - waiting = menunggu konfirmasi
// - booked = sudah dikonfirmasi
// - ongoing = sedang diproses (barber sedang potong)
// - served = selesai
// - cancelled = dibatalkan
enum QueueStatus { waiting, booked, ongoing, served, cancelled }

// penjelasan extension:
// - extension adalah cara untuk menambah method ke tipe data yang sudah ada
// - ini memungkinkan queuestatus.value dan queuestatus.fromstring() bekerja
// - method value mengkonversi enum menjadi string
// - method fromstring mengkonversi string menjadi enum
extension QueueStatusExtension on QueueStatus {
  // method value: mengubah enum menjadi string
  // contoh: QueueStatus.waiting.value akan menghasilkan 'waiting'
  String get value {
    switch (this) {
      case QueueStatus.waiting:
        return 'waiting';
      case QueueStatus.booked:
        return 'booked';
      case QueueStatus.ongoing:
        return 'ongoing';
      case QueueStatus.served:
        return 'served';
      case QueueStatus.cancelled:
        return 'cancelled';
    }
  }

  // method fromstring: mengubah string menjadi enum
  // ini digunakan ketika mengambil data dari firebase yang berisi string
  // contoh: QueueStatus.fromString('booked') akan menghasilkan QueueStatus.booked
  static QueueStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return QueueStatus.booked;
      case 'ongoing':
        return QueueStatus.ongoing;
      case 'served':
        return QueueStatus.served;
      case 'cancelled':
        return QueueStatus.cancelled;
      default:
        return QueueStatus.waiting;
    }
  }
}

// penjelasan class queue:
// - class adalah blueprint untuk membuat object (data)
// - queue mewakili satu entry dalam antrian booking
// - setiap queue menyimpan informasi: siapa yang booking, barbershop mana, barber siapa, dll
// - final berarti property tidak bisa diubah setelah dibuat (immutable)
class Queue {
  // penjelasan property:
  final String id;                          // id unik dari database
  final String barbershopId;                // id barbershop yang dipilih
  final String customerId;                  // id customer yang booking
  final String barbermanId;                 // id barber yang akan melayani

  final Timestamp bookingTime;              // waktu booking dibuat
  final Timestamp? startTime;               // waktu barber mulai (nullable = bisa null)
  final Timestamp? finishTime;              // waktu barber selesai

  final int? actualDuration;                // durasi sebenarnya (berapa lama diproses)
  final int? estimatedDuration;             // durasi estimasi awal

  final List<String>? serviceIds;           // list id layanan yang dipilih (bisa 1 atau lebih)
  final String? serviceId;                  // fallback untuk 1 layanan (model lama)
  final int? totalPrice;                    // total harga semua layanan

  final QueueStatus status;                 // status booking (waiting/booked/ongoing/served/cancelled)
  final Timestamp? createdAt;               // waktu record dibuat
  final String? paymentProofBase64;         // bukti pembayaran dalam bentuk base64

  // penjelasan constructor:
  // - constructor adalah method khusus untuk membuat object dari class ini
  // - parameter required harus diberikan, parameter lain opsional
  // - ini memastikan setiap queue selalu memiliki data penting
  Queue({
    required this.id,
    required this.barbershopId,
    required this.customerId,
    required this.barbermanId,
    required this.bookingTime,
    this.startTime,
    this.finishTime,
    this.actualDuration,
    this.estimatedDuration,
    this.serviceIds,
    this.serviceId,
    this.totalPrice,
    required this.status,
    this.createdAt,
    this.paymentProofBase64,
  });

  // penjelasan getter firstserviceid:
  // - getter adalah method yang diakses seperti property (tanpa ())
  // - firstserviceid mengembalikan service pertama dari list
  // - jika serviceids kosong, ambil serviceId (fallback model lama)
  // - contoh: queue.firstServiceId akan menampilkan id service pertama
  String? get firstServiceId {
    if (serviceIds != null && serviceIds!.isNotEmpty) return serviceIds!.first;
    return serviceId;
  }

  // penjelasan factory queue.fromfirestore:
  // - factory adalah constructor khusus untuk membuat object dari data luar
  // - ini mengambil data dari firebase (DocumentSnapshot) dan mengubahnya menjadi object Queue
  // - readstring dan readstringlist adalah helper function untuk handle null value
  // - ?? adalah operator null coalesce (jika kiri null, ambil kanan)
  // - ini penting untuk kompatibilitas dengan format field yang berbeda di database
  factory Queue.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    // helper function untuk mengubah dynamic value menjadi string
    // jika value null, kembalikan string kosong ''
    String readString(dynamic v) => (v == null) ? '' : v.toString();

    // helper function untuk mengubah dynamic value menjadi list of string
    // jika value list, convert setiap item menjadi string
    List<String>? readStringList(dynamic v) {
      if (v == null) return null;
      if (v is List) return v.map((e) => e.toString()).toList();
      return null;
    }

    // buat queue object dari data firebase
    return Queue(
      id: doc.id,
      // coba field name snake_case dulu (barbershop_id), jika tidak ada pakai camelCase (barbershopId)
      barbershopId: readString(data['barbershop_id'] ?? data['barbershopId']),
      customerId: readString(data['customer_id'] ?? data['customerId']),
      barbermanId: readString(data['barberman_id'] ?? data['barbermanId']),
      // bookingtime adalah timestamp (waktu). cast as Timestamp, jika tidak ada gunakan waktu sekarang
      bookingTime: (data['booking_time'] as Timestamp?) ??
          (data['bookingTime'] as Timestamp?) ??
          Timestamp.now(),
      startTime: (data['start_time'] as Timestamp?) ??
          (data['startTime'] as Timestamp?),
      finishTime: (data['finish_time'] as Timestamp?) ??
          (data['finishTime'] as Timestamp?),
      // durasi adalah number, cast ke int menggunakan toInt()
      actualDuration: (data['actual_duration'] as num?)?.toInt() ??
          (data['actualDuration'] as num?)?.toInt(),
      estimatedDuration: (data['estimated_duration'] as num?)?.toInt() ??
          (data['estimatedDuration'] as num?)?.toInt(),
      serviceIds: readStringList(data['service_ids'] ?? data['serviceIds']),
      serviceId: readString(data['service_id'] ?? data['serviceId']),
      totalPrice: (data['total_price'] as num?)?.toInt() ??
          (data['totalPrice'] as num?)?.toInt(),
      // konversi string status menjadi enum menggunakan .fromString()
      status: QueueStatusExtension.fromString(readString(data['status'])),
      createdAt: (data['created_at'] as Timestamp?) ??
          (data['createdAt'] as Timestamp?),
      paymentProofBase64:
          readString(data['payment_proof_base64'] ?? data['paymentProofBase64']),
    );
  }

  // penjelasan method tojson:
  // - method ini mengubah object Queue menjadi Map (dictionary)
  // - digunakan saat menyimpan ke firebase
  // - removeWhere((_, v) => v == null) menghapus field yang null (menghemat storage)
  // - status.value mengkonversi enum status menjadi string
  // - fieldvalue.servertimestamp() membuat firebase set waktu otomatis saat penyimpanan
  Map<String, dynamic> toJson() {
    final data = {
      'barbershop_id': barbershopId,
      'customer_id': customerId,
      'barberman_id': barbermanId,
      'booking_time': bookingTime,
      'start_time': startTime,
      'finish_time': finishTime,
      'actual_duration': actualDuration,
      'estimated_duration': estimatedDuration,
      'service_ids': serviceIds,
      'service_id': serviceId,
      'total_price': totalPrice,
      'status': status.value,  // ubah enum jadi string
      'created_at': createdAt ?? FieldValue.serverTimestamp(),
      'payment_proof_base64': paymentProofBase64,
    };
    // buang field yang bernilai null agar database tidak penuh dengan data kosong
    data.removeWhere((_, v) => v == null);
    return data;
  }

  // penjelasan method copywith:
  // - method ini membuat salinan object Queue dengan beberapa property yang berubah
  // - sangat berguna untuk update 1-2 field tanpa buat ulang object dari awal
  // - contoh: queue.copyWith(status: QueueStatus.served) = buat queue baru dengan status served saja
  Queue copyWith({
    String? id,
    String? barbershopId,
    String? customerId,
    String? barbermanId,
    Timestamp? bookingTime,
    Timestamp? startTime,
    Timestamp? finishTime,
    int? actualDuration,
    int? estimatedDuration,
    List<String>? serviceIds,
    String? serviceId,
    int? totalPrice,
    QueueStatus? status,
    Timestamp? createdAt,
    String? paymentProofBase64,
  }) {
    return Queue(
      id: id ?? this.id,
      barbershopId: barbershopId ?? this.barbershopId,
      customerId: customerId ?? this.customerId,
      barbermanId: barbermanId ?? this.barbermanId,
      bookingTime: bookingTime ?? this.bookingTime,
      startTime: startTime ?? this.startTime,
      finishTime: finishTime ?? this.finishTime,
      actualDuration: actualDuration ?? this.actualDuration,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      serviceIds: serviceIds ?? this.serviceIds,
      serviceId: serviceId ?? this.serviceId,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      paymentProofBase64: paymentProofBase64 ?? this.paymentProofBase64,
    );
  }
}
