
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart'; // Ensure this package is available or mock Auth otherwise
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/customer/booking_detail_screen.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Sample Base64 Image (1x1 Red Pixel)
const String kSampleImageBase64 = 
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late QueueService queueService;
  late BarbershopService barbershopService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'cust123'));
    queueService = QueueService(firestore: fakeFirestore, auth: mockAuth);
    barbershopService = BarbershopService(firestore: fakeFirestore);
  });

  testWidgets('Alur Lengkap: Request Refund -> Admin Approve (Bukti Gambar) -> Cek UI Bukti', (WidgetTester tester) async {
    // Set Surface Size to typical phone height
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bookingTime = DateTime.now().add(const Duration(days: 1));
    final queueId = 'queue_001';
    
    // 1. SEED DATABASE
    await fakeFirestore.collection('queues').doc(queueId).set({
      'customer_id': 'cust123',
      'barbershop_id': 'shop1',
      'barberman_id': 'barber1',
      'service_ids': ['cut'],
      'status': 'booked', 
      'total_price': 50000,
      'booking_time': Timestamp.fromDate(bookingTime),
      'payment_proof_base64': kSampleImageBase64,
      'verified_by': 'admin',
      'created_at': FieldValue.serverTimestamp(),
    });

    await fakeFirestore.collection('barbershops').doc('shop1').set({'name': 'Geges Barber', 'address': 'Jl. Test'});
    await fakeFirestore.collection('services').doc('cut').set({'name': 'Haircut', 'price': 50000});
    await fakeFirestore.collection('barbermen').doc('barber1').set({'name': 'Budi', 'photo_url': 'http://test.com/budi.jpg'});

    // 2. OPEN DETAIL (TERJADWAL) - Inject Services
    await tester.pumpWidget(MaterialApp(
      home: BookingDetailScreen(
        queueId: queueId,
        queueService: queueService,
        barbershopService: barbershopService,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TERJADWAL'), findsOneWidget);
    expect(find.text('MINTA REFUND / BATAL'), findsOneWidget);

    // 3. REQUEST CANCELLATION
    await tester.ensureVisible(find.text('MINTA REFUND / BATAL'));
    await tester.tap(find.text('MINTA REFUND / BATAL'));
    await tester.pumpAndSettle();
    
    // Ensure dialog appears
    expect(find.text('Minta Refund'), findsOneWidget);
    
    await tester.enterText(find.byType(TextField), "Salah jadwal");
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    // Verify DB
    final docReq = await fakeFirestore.collection('queues').doc(queueId).get();
    expect(docReq.data()?['status'], 'cancellation_requested');
    expect(docReq.data()?['cancellation_reason'], 'Salah jadwal');

    // 4. ADMIN APPROVE & UPLOAD PROOF (Simulated)
    // Simulate admin processing via backend/service
    await fakeFirestore.collection('queues').doc(queueId).update({
      'status': 'cancelled', // or refund_completed
      'is_refunded': true,
      'refund_reason': 'Refund disetujui',
      'refund_proof_base64': kSampleImageBase64,
      'refunded_at': FieldValue.serverTimestamp(),
      'payment_proof_base64': FieldValue.delete(),
    });

    // 5. RELOAD DETAIL
    // Re-pump widget to reflect changes (simulating navigation back/forth or stream update)
    // Since it's a StreamBuilder, it might update automatically if fakeFirestore triggers stream.
    // fake_cloud_firestore streams usually update automatically.
    await tester.pumpAndSettle();

    // 6. FINAL VERIFICATION
    expect(find.text('DIBATALKAN'), findsOneWidget);
    expect(find.text('INFORMASI PEMBATALAN / REFUND'), findsOneWidget);
    expect(find.text('Alasan: Refund disetujui'), findsOneWidget);
    expect(find.text('Bukti Refund:'), findsOneWidget);
    
    // Find the Image widget logic
    // We expect a GestureDetector wrapping a Container with DecorationImage
    // or just find the Icon zoom_in which we added
    expect(find.byIcon(Icons.zoom_in), findsOneWidget); 
    
    // Tap to Zoom
    await tester.tap(find.byIcon(Icons.zoom_in));
    await tester.pumpAndSettle();
    
    // Check if Dialog opened with InteractiveViewer
    expect(find.byType(InteractiveViewer), findsOneWidget); 
    
    // Clean up button presence
    expect(find.text('HAPUS PESANAN'), findsOneWidget);
  });
}
