// lib/models/booking_details.dart (Simulasi data gabungan)
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model ringkas Booking/Queue untuk keperluan UI.
class BookingDetails {
  final String id;
  final String barbershopId;
  final String customerId;
  final String? barbermanId;
  final List<String> serviceIds;
  final int? totalPrice;
  final int? estimatedDuration; // in minutes
  final Timestamp bookingTime;
  final String status; // waiting | booked | ongoing | served | cancelled
  final Timestamp? paymentDueAt; // when payment must be completed
  final Timestamp? paymentSubmittedAt;
  final String? paymentProofBase64;
  final String? paymentMethod;
  final String? cancellationReason;
  final String? cancelledByUid;
  final Timestamp? cancelledAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final double? rating;

  BookingDetails({
    required this.id,
    required this.barbershopId,
    required this.customerId,
    this.barbermanId,
    required this.serviceIds,
    this.totalPrice,
    this.estimatedDuration,
    required this.bookingTime,
    required this.status,
    this.paymentDueAt,
    this.paymentSubmittedAt,
    this.paymentProofBase64,
    this.paymentMethod,
    this.cancellationReason,
    this.cancelledByUid,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
    this.rating,
  });

  factory BookingDetails.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? {};
    return BookingDetails(
      id: snap.id,
      barbershopId: data['barbershop_id'] as String? ?? '',
      customerId: data['customer_id'] as String? ?? '',
      barbermanId: data['barberman_id'] as String?,
      serviceIds: ((data['service_ids'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
      totalPrice: (data['total_price'] as num?)?.toInt(),
      estimatedDuration: (data['estimated_duration'] as num?)?.toInt(),
      bookingTime: data['booking_time'] is Timestamp ? data['booking_time'] as Timestamp : Timestamp.now(),
      status: data['status'] as String? ?? 'waiting',
      paymentDueAt: data['payment_due_at'] as Timestamp?,
      paymentSubmittedAt: data['payment_submitted_at'] as Timestamp?,
      paymentProofBase64: data['payment_proof_base64'] as String?,
      paymentMethod: data['payment_method'] as String?,
      cancellationReason: data['cancellation_reason'] as String?,
      cancelledByUid: data['cancelled_by_uid'] as String?,
      cancelledAt: data['cancelled_at'] as Timestamp?,
      createdAt: data['created_at'] as Timestamp?,
      updatedAt: data['updated_at'] as Timestamp?,
      rating: (data['rating'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barbershop_id': barbershopId,
      'customer_id': customerId,
      'barberman_id': barbermanId,
      'service_ids': serviceIds,
      'total_price': totalPrice,
      'estimated_duration': estimatedDuration,
      'booking_time': bookingTime,
      'status': status,
      'payment_due_at': paymentDueAt,
      'payment_submitted_at': paymentSubmittedAt,
      'payment_proof_base64': paymentProofBase64,
      'payment_method': paymentMethod,
      'cancellation_reason': cancellationReason,
      'cancelled_by_uid': cancelledByUid,
      'cancelled_at': cancelledAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'rating': rating,
    }..removeWhere((_, v) => v == null);
  }
}
