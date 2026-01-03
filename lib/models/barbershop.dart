import 'package:cloud_firestore/cloud_firestore.dart';

class Barbershop {
  final String id;
  final String name;
  final String addres;
  final double rating;
  final String imageUrl; // Utama
  final List<String> services;
  final List<String> facilities; // Fasilitas (AC, Wifi, etc)
  final List<String> galleryUrls; // Album (Base64)
  final int openHour;
  final int closeHour;
  final int? paymentWindowMinutes;
  final int? specialOrderFee;
  final int barberSelectionFee; 
  final bool isOpen;
  final List<int> weeklyHolidays; 
  final List<String> specificHolidays; 

  Barbershop({
    required this.id,
    required this.name,
    required this.addres,
    required this.rating,
    required this.imageUrl,
    required this.services,
    this.facilities = const [],
    this.galleryUrls = const [],
    required this.openHour,
    required this.closeHour,
    this.paymentWindowMinutes,
    this.specialOrderFee,
    this.barberSelectionFee = 5000,
    required this.isOpen,
    this.weeklyHolidays = const [],
    this.specificHolidays = const [],
  });

  factory Barbershop.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    int parseHour(dynamic value, int fallback) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is String) {
        if (value.contains(':')) return int.tryParse(value.split(':').first) ?? fallback;
        return int.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    return Barbershop(
      id: doc.id,
      name: data['name'] ?? 'Nama Barbershop',
      addres: (data['address'] ?? data['addres'] ?? 'Alamat Tidak Diketahui') as String,
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      imageUrl: data['imageUrl'] ?? 'https://cdn-icons-png.flaticon.com/512/706/706830.png',
      services: List<String>.from(data['services'] ?? []),
      facilities: List<String>.from(data['facilities'] ?? []),
      galleryUrls: List<String>.from(data['gallery_urls'] ?? data['galleryUrls'] ?? []),
      openHour: parseHour(data['open_hour'] ?? data['openHour'], 9),
      closeHour: parseHour(data['close_hour'] ?? data['closeHour'], 21),
      paymentWindowMinutes: (data['payment_window_minutes'] ?? data['paymentWindowMinutes'])?.toInt(),
      specialOrderFee: (data['special_order_fee'] ?? data['specialOrderFee'])?.toInt(),
      barberSelectionFee: (data['barber_selection_fee'] ?? data['barberSelectionFee'])?.toInt() ?? 5000,
      isOpen: data['isOpen'] as bool? ?? false,
      weeklyHolidays: List<int>.from(data['weekly_holidays'] ?? data['weeklyHolidays'] ?? []),
      specificHolidays: List<String>.from(data['specific_holidays'] ?? data['specific_holidays'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': addres, // Consistent field name
      'rating': rating,
      'imageUrl': imageUrl,
      'services': services,
      'facilities': facilities,
      'gallery_urls': galleryUrls,
      'open_hour': openHour,
      'close_hour': closeHour,
      'payment_window_minutes': paymentWindowMinutes,
      'special_order_fee': specialOrderFee,
      'barber_selection_fee': barberSelectionFee,
      'isOpen': isOpen,
      'weekly_holidays': weeklyHolidays,
      'specific_holidays': specificHolidays,
    };
  }
}
