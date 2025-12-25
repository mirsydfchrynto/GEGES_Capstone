// lib/models/barberman.dart
// dokumentasi: model untuk data barber (tukang potong rambut)

import 'package:cloud_firestore/cloud_firestore.dart';

// Enum hari dalam seminggu
enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

// Enum tipe cuti
enum LeaveType { weeklyOff, annual, sick, personal, other }

// Enum hari dalam seminggu

// Enum tipe cuti

// penjelasan class barberman:
// - merepresentasikan satu barber (tukang potong rambut)
// - menyimpan info: nama, barbershop, rating, durasi potong rata-rata, dll
// - avgduration penting untuk estimasi waktu booking dan forecasting
// - rating penting untuk rekomendasi barber terbaik
class Barberman {
  // penjelasan property:
  final String id; // id unik barber (dari firebase)
  final String name; // nama barber (contoh: "andi")
  final String barbershopId; // id barbershop tempat barber bekerja
  final String? imageUrl; // url foto barber (nullable, bisa tidak ada)
  final double avgDuration; // rata-rata durasi potong (menit)
  final double rating; // rating barber (0.0 - 5.0)
  final bool isActive; // apakah barber sedang aktif/bisa dipesan
  final List<DayOfWeek>? offDays; // hari libur mingguan
  final int annualLeaveDays; // sisa cuti tahunan
  final bool onLeave; // sedang cuti atau tidak

  // Enum hari dalam seminggu

  // Enum tipe cuti
  // penjelasan constructor:
  // - imageurl nullable (boleh null)
  // - sisanya required (harus diberikan)
  Barberman({
    required this.id,
    required this.name,
    required this.barbershopId,
    this.imageUrl,
    required this.avgDuration,
    required this.rating,
    required this.isActive,
    this.offDays,
    this.annualLeaveDays = 12,
    this.onLeave = false,
  });

  // penjelasan factory barberman.fromfirestore:
  // - convert firebase document menjadi object barberman
  // - doc.data() ?? {} = ambil data atau gunakan map kosong jika null
  factory Barberman.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final avgDur =
        (data['avg_duration'] as num?)?.toDouble() ??
        (data['avgDuration'] as num?)?.toDouble() ??
        30.0;

    // Parse offDays jika ada
    List<DayOfWeek>? offDays;
    if (data['offDays'] != null && data['offDays'] is List) {
      offDays = (data['offDays'] as List)
          .map(
            (e) => DayOfWeek.values.firstWhere(
              (d) => d.name == e,
              orElse: () => DayOfWeek.monday,
            ),
          )
          .toList();
    }

    return Barberman(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? 'Barberman Tidak Dikenal',
      barbershopId:
          data['barbershop_id'] as String? ??
          data['barbershopId'] as String? ??
          '',
      imageUrl: data['imageUrl'] as String?,
      avgDuration: avgDur,
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      isActive: data['isActive'] as bool? ?? true,
      offDays: offDays,
      annualLeaveDays: data['annualLeaveDays'] as int? ?? 12,
      onLeave: data['onLeave'] as bool? ?? false,
    );
  }

  // penjelasan method tojson:
  // - convert object menjadi map untuk simpan ke firebase
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'barbershop_id': barbershopId,
      'imageUrl': imageUrl,
      'avg_duration': avgDuration,
      'rating': rating,
      'isActive': isActive,
      // Serialize offDays as list of string names
      if (offDays != null) 'offDays': offDays!.map((d) => d.name).toList(),
      'annualLeaveDays': annualLeaveDays,
      'onLeave': onLeave,
    };
  }
}
