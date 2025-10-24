import 'package:cloud_firestore/cloud_firestore.dart';

class Queue {
  final String id;
  final String barbershopId;
  final String customerId;
  final String barbermanId;
  final Timestamp bookingTime;
  final Timestamp? startTime;
  final Timestamp? finishTime;
  final int? actualDuration; // Hasil input dari Admin/Kasir
  final String status; // <-- FIELD YANG HILANG SUDAH DITAMBAHKAN

  Queue({
    required this.id,
    required this.barbershopId,
    required this.customerId,
    required this.barbermanId,
    required this.bookingTime,
    this.startTime,
    this.finishTime,
    this.actualDuration,
    required this.status, // <-- TAMBAHKAN DI KONSTRUKTOR
  });

  factory Queue.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Queue(
      id: doc.id,
      barbershopId: data['barbershop_id'] ?? '',
      customerId: data['customer_id'] ?? '',
      barbermanId: data['barberman_id'] ?? '',
      bookingTime: data['booking_time'] as Timestamp,
      startTime: data['start_time'] as Timestamp?,
      finishTime: data['finish_time'] as Timestamp?,
      actualDuration: (data['actual_duration'] as num?)?.toInt(),
      // <-- TAMBAHKAN LOGIKA PENGAMBILAN STATUS DARI FIRESTORE
      // Jika status tidak ada di database, anggap 'pending'
      status: data['status'] ?? 'pending', 
    );
  }
}
