import 'package:cloud_firestore/cloud_firestore.dart';

enum DayOfWeek { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

class Barberman {
  final String id;
  final String name;
  final String barbershopId;
  final String? imageUrl;
  final double avgDuration;
  final double rating;
  final bool isActive;
  final List<DayOfWeek>? offDays;
  final List<String> specificOffDays; // New: ["2025-05-20"]
  final int monthlyHaircutCount; // New: for fairness formula
  final int annualLeaveDays;
  final bool onLeave;
  final int age;

  Barberman({
    required this.id,
    required this.name,
    required this.barbershopId,
    this.imageUrl,
    required this.avgDuration,
    required this.rating,
    required this.isActive,
    this.offDays,
    this.specificOffDays = const [],
    this.monthlyHaircutCount = 0,
    this.annualLeaveDays = 12,
    this.onLeave = false,
    this.age = 0,
  });

  factory Barberman.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final avgDur = (data['avg_duration'] ?? data['avgDuration'] ?? 30.0) as num;

    List<DayOfWeek>? offDays;
    if (data['offDays'] != null && data['offDays'] is List) {
      offDays = (data['offDays'] as List).map((e) => DayOfWeek.values.firstWhere((d) => d.name == e, orElse: () => DayOfWeek.monday)).toList();
    }

    return Barberman(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? 'Barberman Tidak Dikenal',
      barbershopId: (data['barbershop_id'] ?? data['barbershopId'] ?? '') as String,
      imageUrl: data['imageUrl'] as String?,
      avgDuration: avgDur.toDouble(),
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      isActive: data['isActive'] as bool? ?? true,
      offDays: offDays,
      specificOffDays: List<String>.from(data['specificOffDays'] ?? []),
      monthlyHaircutCount: data['monthly_haircut_count'] ?? data['monthlyHaircutCount'] ?? 0,
      annualLeaveDays: data['annualLeaveDays'] as int? ?? 12,
      onLeave: data['onLeave'] as bool? ?? false,
      age: data['age'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'barbershop_id': barbershopId,
      'imageUrl': imageUrl,
      'avg_duration': avgDuration,
      'rating': rating,
      'isActive': isActive,
      if (offDays != null) 'offDays': offDays!.map((d) => d.name).toList(),
      'specificOffDays': specificOffDays,
      'monthly_haircut_count': monthlyHaircutCount,
      'annualLeaveDays': annualLeaveDays,
      'onLeave': onLeave,
      'age': age,
    };
  }
}