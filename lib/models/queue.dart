import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// FILE: queue.dart (MODEL QUEUE - BOOKING & REQUEST BOOKING)
/// ============================================================================
///
/// ALUR BOOKING FLOW BARU (PHASE 3):
///
/// 1. CUSTOMER REQUEST BOOKING
///    - Customer memilih barbershop, service, tanggal & jam
///    - Status: 'waiting' (menunggu approval dari admin)
///    - Belum ada pembayaran, no uang yang masuk
///
/// 2. ADMIN CONFIRMATION
///    - Admin melihat request booking di dashboard
///    - Admin cek ketersediaan barberman & slot di jam tersebut
///    - Admin approve/reject request
///    - Jika approve: status berubah 'booked' → customer dapat notif untuk bayar
///    - Jika reject: status berubah 'cancelled' → customer tidak perlu bayar
///
/// 3. PAYMENT WINDOW (dalam kurung waktu tertentu, misal: 1 jam)
///    - Customer wajib upload bukti pembayaran dalam waktu window ini
///    - Field 'paymentDeadline' tracking kapan window tutup
///    - Jika timeout: request auto-cancelled (payment_timeout_cancelled)
///    - Jika bayar: status 'payment_pending' → menunggu admin verifikasi
///
/// 4. ADMIN PAYMENT VERIFICATION
///    - Admin cek bukti pembayaran (sama seperti current flow)
///    - Admin approve payment: status 'ongoing' → siap dilayani
///    - Admin reject payment: status 'cancelled', customer bisa request ulang
///
/// 5. SELESAI
///    - Barber mulai: status 'ongoing'
///    - Barber selesai: status 'served'
///
/// STATUS VALUES EXPLANATION:
/// - 'waiting': Menunggu approval dari admin (request booking baru)
/// - 'booked': Admin sudah approve, customer bisa bayar sekarang
/// - 'payment_pending': Customer sudah upload bukti pembayaran, tunggu admin cek
/// - 'ongoing': Admin approve pembayaran, barber sedang melayani
/// - 'served': Selesai dilayani
/// - 'cancelled': Dibatalkan (reject admin, atau payment timeout, atau tolak payment)
///
/// PERUBAHAN DATABASE FIELD:
/// - Add: 'request_status' ('pending', 'approved', 'rejected') - tracking approval admin
/// - Add: 'payment_deadline' (Timestamp) - kapan window pembayaran tutup
/// - Add: 'payment_method' (String: 'manual', 'digital') - untuk future digital payment
/// - Add: 'rejection_reason' (String) - alasan jika admin reject
/// - Add: 'verified_by' (String: userId admin) - admin yang verify
/// - Modify: 'status' enum tetap sama, tapi interpretasi berubah
///
/// ============================================================================

// penjelasan enum queuestatus:
// - enum adalah tipe data yang memiliki beberapa pilihan nilai tetap
// - queuestatus hanya bisa bernilai: waiting, booked, ongoing, served, atau cancelled
// - ini memastikan status booking hanya bisa salah satu dari pilihan tersebut
// - waiting = menunggu konfirmasi admin
// - booked = sudah dikonfirmasi, customer bisa bayar
// - ongoing = pembayaran approve, sedang diproses (barber sedang potong)
// - served = selesai
// - cancelled = dibatalkan (reject admin / payment timeout / payment tolak)
enum QueueStatus { waiting, booked, ongoing, served, cancelled }

// penjelasan enum requeststatus:
// - tracking approval dari admin untuk request booking
// - pending = menunggu admin lihat & approve/reject
// - approved = admin approve, customer wajib bayar
// - rejected = admin reject, request hangus, tidak ada pembayaran
enum RequestStatus { pending, approved, rejected }

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
      // Common finalized states
      case 'booked':
      case 'paid_verified':
      case 'payment_confirmed':
      case 'confirmed':
      case 'awaiting_payment':
      case 'payment_pending':
        // Treat these as the "booked" bucket for UI/processing purposes
        return QueueStatus.booked;
      case 'ongoing':
        return QueueStatus.ongoing;
      case 'served':
        return QueueStatus.served;
      case 'cancelled':
        return QueueStatus.cancelled;
      case 'created':
      case 'waiting':
      default:
        return QueueStatus.waiting;
    }
  }
}

/// Extension untuk RequestStatus (tracking admin approval)
/// Method ini membantu convert enum ke string & sebaliknya
extension RequestStatusExtension on RequestStatus {
  // method value: mengubah enum menjadi string
  // contoh: RequestStatus.pending.value akan menghasilkan 'pending'
  String get value {
    switch (this) {
      case RequestStatus.pending:
        return 'pending';
      case RequestStatus.approved:
        return 'approved';
      case RequestStatus.rejected:
        return 'rejected';
    }
  }

  // method fromstring: mengubah string menjadi enum
  static RequestStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return RequestStatus.approved;
      case 'rejected':
        return RequestStatus.rejected;
      default:
        return RequestStatus.pending;
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
  final String id; // id unik dari database
  final String barbershopId; // id barbershop yang dipilih
  final String customerId; // id customer yang booking
  final String barbermanId; // id barber yang akan melayani

  final Timestamp bookingTime; // waktu booking dibuat
  final Timestamp? startTime; // waktu barber mulai (nullable = bisa null)
  final Timestamp? finishTime; // waktu barber selesai

  final int? actualDuration; // durasi sebenarnya (berapa lama diproses)
  final int? estimatedDuration; // durasi estimasi awal

  final List<String>?
  serviceIds; // list id layanan yang dipilih (bisa 1 atau lebih)
  final String? serviceId; // fallback untuk 1 layanan (model lama)
  final int? totalPrice; // total harga semua layanan
  // barber selection fee (Rp)
  final int? barberSelectionFee; // tambahan bila user memilih barber berbayar
  final bool? paidBarberSelection; // apakah barber dipilih dengan opsi berbayar

  final QueueStatus
  status; // status booking (waiting/booked/ongoing/served/cancelled)

  // ============ NEW FIELDS FOR BOOKING FLOW ============
  final RequestStatus
  requestStatus; // status approval dari admin (pending/approved/rejected)
  final Timestamp?
  paymentDeadline; // kapan window pembayaran harus selesai (1 jam dari approve)
  final String? paymentMethod; // 'manual' atau 'digital' (future use)
  final String?
  rejectionReason; // alasan jika admin reject request atau payment
  final String? verifiedBy; // userId admin yang verify payment
  // ====================================================

  final Timestamp? createdAt; // waktu record dibuat
  final String? paymentProofBase64; // bukti pembayaran dalam bentuk base64
  final String?
  paymentProofUrl; // bukti pembayaran sebagai URL (jika diupload via admin anti-dup service)
  // ============ REFUND FIELDS ============
  final bool? isRefunded; // apakah booking sudah di-refund
  final Timestamp? refundedAt; // waktu refund diproses
  final String? refundReason; // alasan refund (cancelled, rejected, etc)
  final String? refundedBy; // admin uid yang process refund
  // ======================================

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
    this.barberSelectionFee,
    this.paidBarberSelection,
    required this.status,
    required this.requestStatus,
    this.paymentDeadline,
    this.paymentMethod,
    this.rejectionReason,
    this.verifiedBy,
    this.createdAt,
    this.paymentProofBase64,
    this.paymentProofUrl,
    this.isRefunded,
    this.refundedAt,
    this.refundReason,
    this.refundedBy,
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
      bookingTime:
          (data['booking_time'] as Timestamp?) ??
          (data['bookingTime'] as Timestamp?) ??
          Timestamp.now(),
      startTime:
          (data['start_time'] as Timestamp?) ??
          (data['startTime'] as Timestamp?),
      finishTime:
          (data['finish_time'] as Timestamp?) ??
          (data['finishTime'] as Timestamp?),
      // durasi adalah number, cast ke int menggunakan toInt()
      actualDuration:
          (data['actual_duration'] as num?)?.toInt() ??
          (data['actualDuration'] as num?)?.toInt(),
      estimatedDuration:
          (data['estimated_duration'] as num?)?.toInt() ??
          (data['estimatedDuration'] as num?)?.toInt(),
      serviceIds: readStringList(data['service_ids'] ?? data['serviceIds']),
      serviceId: readString(data['service_id'] ?? data['serviceId']),
      totalPrice:
          (data['total_price'] as num?)?.toInt() ??
          (data['totalPrice'] as num?)?.toInt(),
      // NEW: barber selection fee & flag
      barberSelectionFee:
          (data['barber_selection_fee'] as num?)?.toInt() ??
          (data['barberSelectionFee'] as num?)?.toInt(),
      paidBarberSelection:
          (data['paid_barber_selection'] as bool?) ??
          (data['paidBarberSelection'] as bool?) ??
          false,
      // konversi string status menjadi enum menjadi enum menggunakan .fromString()
      status: QueueStatusExtension.fromString(readString(data['status'])),
      // NEW: request status tracking (default: pending jika tidak ada)
      requestStatus: RequestStatusExtension.fromString(
        readString(
          data['request_status'] ?? data['requestStatus'] ?? 'pending',
        ),
      ),
      // NEW: payment deadline tracking
      paymentDeadline:
          (data['payment_deadline'] as Timestamp?) ??
          (data['paymentDeadline'] as Timestamp?),
      // NEW: payment method tracking (manual/digital)
      paymentMethod: readString(
        data['payment_method'] ?? data['paymentMethod'],
      ),
      // NEW: rejection reason dari admin
      rejectionReason: readString(
        data['rejection_reason'] ?? data['rejectionReason'],
      ),
      // NEW: admin yang verify payment
      verifiedBy: readString(data['verified_by'] ?? data['verifiedBy']),
      createdAt:
          (data['created_at'] as Timestamp?) ??
          (data['createdAt'] as Timestamp?),
      paymentProofBase64: readString(
        data['payment_proof_base64'] ?? data['paymentProofBase64'],
      ),
      paymentProofUrl: readString(
        (data['payment'] is Map)
            ? (data['payment']['proofUrl'] ?? data['payment']['proof_url'])
            : data['payment_proof_url'],
      ),
      // NEW: refund fields
      isRefunded:
          (data['is_refunded'] as bool?) ??
          (data['isRefunded'] as bool?) ??
          false,
      refundedAt:
          (data['refunded_at'] as Timestamp?) ??
          (data['refundedAt'] as Timestamp?),
      refundReason: readString(data['refund_reason'] ?? data['refundReason']),
      refundedBy: readString(data['refunded_by'] ?? data['refundedBy']),
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
      'barber_selection_fee': barberSelectionFee,
      'paid_barber_selection': paidBarberSelection,
      'status': status.value, // ubah enum jadi string
      // NEW: request status tracking
      'request_status': requestStatus.value,
      'payment_deadline': paymentDeadline,
      'payment_method': paymentMethod,
      'rejection_reason': rejectionReason,
      'verified_by': verifiedBy,
      'created_at': createdAt ?? FieldValue.serverTimestamp(),
      'payment_proof_base64': paymentProofBase64,
      'is_refunded': isRefunded ?? false,
      'refunded_at': refundedAt,
      'refund_reason': refundReason,
      'refunded_by': refundedBy,
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
    int? barberSelectionFee,
    bool? paidBarberSelection,
    QueueStatus? status,
    RequestStatus? requestStatus,
    Timestamp? paymentDeadline,
    String? paymentMethod,
    String? rejectionReason,
    String? verifiedBy,
    Timestamp? createdAt,
    String? paymentProofBase64,
    String? paymentProofUrl,
    bool? isRefunded,
    Timestamp? refundedAt,
    String? refundReason,
    String? refundedBy,
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
      barberSelectionFee: barberSelectionFee ?? this.barberSelectionFee,
      paidBarberSelection: paidBarberSelection ?? this.paidBarberSelection,
      status: status ?? this.status,
      requestStatus: requestStatus ?? this.requestStatus,
      paymentDeadline: paymentDeadline ?? this.paymentDeadline,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      createdAt: createdAt ?? this.createdAt,
      paymentProofBase64: paymentProofBase64 ?? this.paymentProofBase64,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      isRefunded: isRefunded ?? this.isRefunded,
      refundedAt: refundedAt ?? this.refundedAt,
      refundReason: refundReason ?? this.refundReason,
      refundedBy: refundedBy ?? this.refundedBy,
    );
  }
}
