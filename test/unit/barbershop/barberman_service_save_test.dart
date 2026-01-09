import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/barberman_service.dart';
import 'package:geges_smartbarber/models/barberman.dart';

void main() {
  group('BarbermanService.saveBarberman', () {
    late FakeFirebaseFirestore fs;
    late BarbermanService svc;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      svc = BarbermanService(firestore: fs);
    });

    test('saves offDays and onLeave fields', () async {
      final b = Barberman(
        id: '',
        name: 'Candra',
        barbershopId: 'shop1',
        avgDuration: 30,
        rating: 4.7,
        isActive: true,
        offDays: [DayOfWeek.monday, DayOfWeek.wednesday],
        annualLeaveDays: 10,
        onLeave: false,
      );

      await svc.saveBarberman(b);

      final col = await fs.collection('barbermen').get();
      expect(col.docs.length, 1);
      final data = col.docs.first.data();

      expect(data['offDays'], isA<List>());
      expect((data['offDays'] as List).contains('monday'), true);
      expect(data['onLeave'], false);
      expect(data['annualLeaveDays'], 10);
    });
  });
}
