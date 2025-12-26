import 'package:cloud_firestore/cloud_firestore.dart';

class EmailOutboxService {
  final FirebaseFirestore _fs;

  EmailOutboxService({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;

  /// Queue an email to be sent by background worker or Cloud Function.
  Future<void> queueEmail({required String to, required String subject, required String body, Map<String, dynamic>? metadata}) async {
    final payload = {
      'to': to,
      'subject': subject,
      'body': body,
      'metadata': metadata ?? {},
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    };

    await _fs.collection('outbox_emails').add(payload);
  }
}
