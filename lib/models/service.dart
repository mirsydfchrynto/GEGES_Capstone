import 'package:cloud_firestore/cloud_firestore.dart';

class Service {
  final String id;
  final String name;
  final String description;
  final double price;
  final int defaultDuration;
  final bool isActive;

  Service({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.defaultDuration,
    required this.isActive,
  });

  factory Service.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final duration = (data['default_duration'] as num?)?.toInt() ??
                     (data['defaultDuration'] as num?)?.toInt() ??
                     30;
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
    final isActive = data['isActive'] as bool? ?? true;

    return Service(
      id: doc.id,
      name: data['name'] as String? ?? 'Service Unknown',
      description: data['description'] as String? ?? '',
      price: price,
      defaultDuration: duration,
      isActive: isActive,
    );
  }

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
