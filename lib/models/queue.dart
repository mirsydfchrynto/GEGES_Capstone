import 'package:cloud_firestore/cloud_firestore.dart';

enum QueueStatus { waiting, booked, ongoing, served, cancelled }

extension QueueStatusExtension on QueueStatus {
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

class Queue {
  final String id;
  final String barbershopId;
  final String customerId;
  final String barbermanId;

  final Timestamp bookingTime;
  final Timestamp? startTime;
  final Timestamp? finishTime;

  final int? actualDuration; // real saat selesai
  final int? estimatedDuration; // estimasi awal booking

  final List<String>? serviceIds; // prefer list baru
  final String? serviceId; // fallback lama (satu layanan)
  final int? totalPrice;

  final QueueStatus status; // waiting | booked | ongoing | served | cancelled
  final Timestamp? createdAt;
  final String? paymentProofBase64;

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

  String? get firstServiceId {
    if (serviceIds != null && serviceIds!.isNotEmpty) return serviceIds!.first;
    return serviceId;
  }

  factory Queue.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    String readString(dynamic v) => (v == null) ? '' : v.toString();

    List<String>? readStringList(dynamic v) {
      if (v == null) return null;
      if (v is List) return v.map((e) => e.toString()).toList();
      return null;
    }

    return Queue(
      id: doc.id,
      barbershopId: readString(data['barbershop_id'] ?? data['barbershopId']),
      customerId: readString(data['customer_id'] ?? data['customerId']),
      barbermanId: readString(data['barberman_id'] ?? data['barbermanId']),
      bookingTime: (data['booking_time'] as Timestamp?) ??
          (data['bookingTime'] as Timestamp?) ??
          Timestamp.now(),
      startTime: (data['start_time'] as Timestamp?) ??
          (data['startTime'] as Timestamp?),
      finishTime: (data['finish_time'] as Timestamp?) ??
          (data['finishTime'] as Timestamp?),
      actualDuration: (data['actual_duration'] as num?)?.toInt() ??
          (data['actualDuration'] as num?)?.toInt(),
      estimatedDuration: (data['estimated_duration'] as num?)?.toInt() ??
          (data['estimatedDuration'] as num?)?.toInt(),
      serviceIds: readStringList(data['service_ids'] ?? data['serviceIds']),
      serviceId: readString(data['service_id'] ?? data['serviceId']),
      totalPrice: (data['total_price'] as num?)?.toInt() ??
          (data['totalPrice'] as num?)?.toInt(),
      status: QueueStatusExtension.fromString(readString(data['status'])),
      createdAt: (data['created_at'] as Timestamp?) ??
          (data['createdAt'] as Timestamp?),
      paymentProofBase64:
          readString(data['payment_proof_base64'] ?? data['paymentProofBase64']),
    );
  }

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
      'status': status.value,
      'created_at': createdAt ?? FieldValue.serverTimestamp(),
      'payment_proof_base64': paymentProofBase64,
    };
    data.removeWhere((_, v) => v == null);
    return data;
  }

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
