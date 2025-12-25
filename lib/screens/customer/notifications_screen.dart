// lib/screens/customer/notifications_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'booking_detail_screen.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  bool _localNotifInitialized = false;

  @override
  void initState() {
    super.initState();
    _initLocalNotifications();
  }

  Future<void> _initLocalNotifications() async {
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localNotif.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          // payload may contain queueId; we don't navigate here because app may be backgrounded.
        },
      );
      _localNotifInitialized = true;
    } catch (e) {
      debugPrint('Local notifications init failed: $e');
    }
  }

  Future<void> _showLocalNotification(
    String id,
    String title,
    String body,
  ) async {
    if (!_localNotifInitialized) return;
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'geges_channel_01',
          'GeGes Notifications',
          channelDescription: 'Notifications for booking updates',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _localNotif.show(
        id.hashCode,
        title,
        body,
        platformDetails,
        payload: id,
      );
    } catch (e) {
      debugPrint('Failed to show local notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifikasi')),
        body: const Center(
          child: Text('Anda harus login untuk melihat notifikasi'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
      ),
      backgroundColor: kSurface,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Note: avoid server-side orderBy to prevent index requirement errors.
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('user_id', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kBrownAccent),
            );
          }

          // If Firestore returns an error (for example missing index), show friendly message
          if (snapshot.hasError) {
            final err = snapshot.error.toString();
            // Provide helpful hint for index-related errors and fallback option
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Terjadi kesalahan saat memuat notifikasi: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final docs = (snapshot.data?.docs ?? []).toList();
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada notifikasi',
                style: TextStyle(color: kTextGrey),
              ),
            );
          }

          // Sort locally by created_at descending (newest first)
          docs.sort((a, b) {
            final aTs = a.data()['created_at'] as Timestamp?;
            final bTs = b.data()['created_at'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

          // Show system notification for any new (not delivered) notifications
          for (final doc in docs) {
            final data = doc.data();
            try {
              final delivered = data['delivered'] as bool? ?? false;
              if (!delivered) {
                final title = data['title'] as String? ?? 'Notifikasi';
                final body = data['body'] as String? ?? '';
                final queueId = data['queue_id'] as String? ?? '';
                // show local/system notification
                _showLocalNotification(
                  queueId.isNotEmpty ? queueId : doc.id,
                  title,
                  body,
                );
                // mark delivered to avoid duplicates
                doc.reference
                    .update({'delivered': true})
                    .catchError(
                      (e) => debugPrint('Failed to mark delivered: $e'),
                    );
              }
            } catch (e) {
              debugPrint('Error while processing delivered flag: $e');
            }
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final createdAt = d['created_at'] as Timestamp?;
              return ListTile(
                tileColor: Colors.grey[900],
                title: Text(
                  d['title'] ?? '',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d['body'] != null)
                      Text(d['body'], style: const TextStyle(color: kTextGrey)),
                    if (createdAt != null)
                      Text(
                        DateFormat('d MMM HH:mm').format(createdAt.toDate()),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                onTap: () async {
                  // mark as read
                  await docs[i].reference.update({'read': true});
                  final queueId = d['queue_id'] as String?;
                  if (queueId != null) {
                    if (!mounted) return;
                    // Safe: we checked `mounted` immediately after async gap
                    Navigator.push(
                      // ignore: use_build_context_synchronously
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingDetailScreen(queueId: queueId),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
