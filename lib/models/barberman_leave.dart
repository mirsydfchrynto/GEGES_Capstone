import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/models/barberman.dart';
// penjelasan class barberman_leave:
// - menyimpan record cuti/libur untuk satu barberman
// - bisa untuk cuti tahunan, cuti sakit, atau libur khusus
// - setiap record punya tanggal mulai dan tanggal selesai
// - status bisa pending (pending approval), approved, or rejected
class BarbermanLeave {
  final String id;
  final String barbermanId;
  final String barbershopId;
  final Timestamp startDate;
  final Timestamp endDate;
  final LeaveType type;
  final String? reason;
  final String status;
  final String? approvedBy;
  final Timestamp createdAt;
  final Timestamp? approvedAt;
  final int usedDays;

  BarbermanLeave({
    required this.id,
    required this.barbermanId,
    required this.barbershopId,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.reason,
    required this.status,
    this.approvedBy,
    required this.createdAt,
    this.approvedAt,
    required this.usedDays,
  });

  factory BarbermanLeave.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final typeStr = data['type'] as String? ?? 'annual';
    LeaveType leaveType;
    try {
      leaveType = LeaveType.values.firstWhere(
        (e) => e.toString().split('.').last == typeStr,
        orElse: () => LeaveType.annual,
      );
    } catch (e) {
      leaveType = LeaveType.annual;
    }
    return BarbermanLeave(
      id: doc.id,
      barbermanId: data['barbermanId'] as String? ?? data['barberman_id'] as String? ?? '',
      barbershopId: data['barbershopId'] as String? ?? data['barbershop_id'] as String? ?? '',
      startDate: data['startDate'] as Timestamp? ?? Timestamp.now(),
      endDate: data['endDate'] as Timestamp? ?? Timestamp.now(),
      type: leaveType,
      reason: data['reason'] as String?,
      status: data['status'] as String? ?? 'pending',
      approvedBy: data['approvedBy'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      approvedAt: data['approvedAt'] as Timestamp?,
      usedDays: (data['usedDays'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barbermanId': barbermanId,
      'barbershopId': barbershopId,
      'startDate': startDate,
      'endDate': endDate,
      'type': type.toString().split('.').last,
      'reason': reason,
      'status': status,
      'approvedBy': approvedBy,
      'createdAt': createdAt,
      'approvedAt': approvedAt,
      'usedDays': usedDays,
    };
  }

  bool get isApproved => status == 'approved';

  bool isOnLeaveToday() {
    final now = Timestamp.now();
    return now.compareTo(startDate) >= 0 && now.compareTo(endDate) <= 0;
  }

  bool isOnLeaveOnDate(DateTime date) {
    final ts = Timestamp.fromDate(date);
    return ts.compareTo(startDate) >= 0 && ts.compareTo(endDate) <= 0;
  }

  int getDurationInDays() {
    final start = startDate.toDate();
    final end = endDate.toDate();
    return end.difference(start).inDays + 1;
  }
}
