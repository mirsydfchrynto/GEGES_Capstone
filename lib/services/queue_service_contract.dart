import 'package:geges_smartbarber/models/queue.dart';

/// Minimal contract used for injection into UI tests to avoid heavy Firestore deps.
abstract class QueueServiceContract {
  Future<Queue?> getQueueById(String id);
  Future<Queue?> resolveQueueForCustomerByIdOrOrder(String idOrOrderId, String customerId);
  Future<void> submitPaymentProofForQueue({required String queueId, required String userId, required String base64Proof});

  // Called by PaymentScreen when timer expires to cancel a specific queue
  Future<void> cancelQueue(String queueId, {String reason, String? cancelledBy});

  // Called as a fallback to cancel any expired awaiting_payment queues for a customer
  Future<int> cancelExpiredAwaitingPaymentQueuesForCustomer(String customerId);
}
