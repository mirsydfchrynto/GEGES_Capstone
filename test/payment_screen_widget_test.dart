import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service_contract.dart';

class FakeQueueService implements QueueServiceContract {
  final Queue? byId;
  final Queue? byResolve;
  bool submitCalled = false;

  FakeQueueService({this.byId, this.byResolve});

  @override
  Future<Queue?> getQueueById(String id) async => byId;

  @override
  Stream<Queue?> streamQueueById(String id) async* {
    // Return the byId value immediately to simulate a single snapshot
    yield byId;
  }

  @override
  Future<Queue?> resolveQueueForCustomerByIdOrOrder(
    String idOrOrderId,
    String customerId,
  ) async => byResolve;

  @override
  Future<void> submitPaymentProofForQueue({
    required String queueId,
    required String userId,
    required String base64Proof,
  }) async {
    submitCalled = true;
  }

  @override
  Future<void> cancelQueue(
    String queueId, {
    String reason = 'Admin/Barberman Cancellation',
    String? cancelledBy,
  }) async {}

  @override
  Future<int> cancelExpiredAwaitingPaymentQueuesForCustomer(
    String customerId,
  ) async => 0;
}

void main() {
  testWidgets('PaymentScreen shows uploaded state and disables submit', (
    WidgetTester tester,
  ) async {
    final q = Queue(
      id: 'q-1',
      barbershopId: 'shop-1',
      customerId: 'user1',
      barbermanId: '',
      bookingTime: Timestamp.now(),
      status: QueueStatus.waiting,
      requestStatus: RequestStatus.approved,
      paymentDeadline: Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 10)),
      ),
      paymentProofBase64: 'exists',
    );

    final fake = FakeQueueService(byId: q, byResolve: q);

    await tester.pumpWidget(
      MaterialApp(
        home: PaymentScreen(
          orderId: 'order-1',
          totalPrice: 50000,
          queueService: fake,
          testUserId: 'user1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The upload card should show 'Bukti pembayaran sudah diunggah'
    expect(find.text('Bukti pembayaran sudah diunggah'), findsOneWidget);

    // The button label should indicate 'Bukti Terunggah' and be disabled
    expect(find.text('Bukti Terunggah'), findsOneWidget);

    final elevated = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(elevated.onPressed, isNull);
  });
}
