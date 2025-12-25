import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/models/barbershop.dart';

void main() {
  test('Barbershop.fromFirestore parses specialOrderFee', () async {
    final fs = FakeFirebaseFirestore();
    await fs.collection('barbershops').doc('s1').set({
      'name': 'Toko',
      'addres': 'Jl',
      'rating': 4.5,
      'imageUrl': '',
      'services': [],
      'open_hour': 9,
      'close_hour': 21,
      'special_order_fee': 10000,
      'isOpen': true,
    });

    final doc = await fs.collection('barbershops').doc('s1').get();
    final b = Barbershop.fromFirestore(doc);
    expect(b.specialOrderFee, 10000);
  });
}
