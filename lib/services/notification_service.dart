import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geges_smartbarber/services/app_navigator.dart';
import 'package:geges_smartbarber/screens/customer/booking_detail_screen.dart';

/// Lightweight NotificationService to initialize FCM, request permission,
/// obtain the device token and listen to incoming messages.
class NotificationService {
  NotificationService._private();
  static final NotificationService instance = NotificationService._private();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final List<StreamSubscription> _notificationsSubs = [];

  /// Initialize FCM: request permission and register handlers.
  Future<void> init() async {
    await _requestPermission();

    // Get the token and save it in Firestore (associated with current user)
    final token = await _messaging.getToken();
    await _saveTokenToFirestore(token);

    // Initialize local notifications
    await _initLocalNotifications();

      // Handle messages when app in foreground: show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? message.data['title'] as String?;
      final body = message.notification?.body ?? message.data['body'] as String?;
      if ((title != null && title.isNotEmpty) || (body != null && body.isNotEmpty)) {
        _showLocalNotification(title ?? '', body ?? '', message.data);
      }
      // still log for debugging
      developer.log('FCM onMessage received: ${message.messageId} ${message.notification?.title}', name: 'NotificationService');
    });

    // Handle interaction when app opened from a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log('FCM onMessageOpenedApp: ${message.data}', name: 'NotificationService');
      try {
        if (message.data.isNotEmpty) {
          _handleNotificationTap(message.data);
        }
      } catch (e) {
        developer.log('Failed handling onMessageOpenedApp navigation: $e', name: 'NotificationService');
      }
    });

    // Handle app opened from a terminated state via notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        developer.log('FCM initialMessage: ${message.data}', name: 'NotificationService');
        try {
          if (message.data.isNotEmpty) _handleNotificationTap(message.data);
        } catch (e) {
          developer.log('Failed handling initialMessage navigation: $e', name: 'NotificationService');
        }
      }
    });

    // Keep user auth changes in sync: save/remove token on sign in/out
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      // cancel previous listeners
      await _cancelNotificationsListeners();

      if (user != null) {
        final t = await _messaging.getToken();
        await _saveTokenToFirestore(t);
        // start listening to notifications for this user
        _startNotificationsListener(user.uid);
      } else {
        await removeToken();
      }
    });
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      provisional: false,
      sound: true,
    );

    developer.log('FCM permission status: ${settings.authorizationStatus}', name: 'NotificationService');
  }

  Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userRef = _firestore.collection('users').doc(uid);
    try {
      await userRef.set({
        'fcm_token': token,
        'fcm_token_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log('Failed to save FCM token: $e', name: 'NotificationService');
    }
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    try {
      await _local.initialize(settings, onDidReceiveNotificationResponse: (resp) {
          // handle tap on local notification: parse payload and navigate
          if (resp.payload != null && resp.payload!.isNotEmpty) {
            try {
              final Map<String, dynamic> data = Map<String, dynamic>.from(Uri.splitQueryString(resp.payload!));
              _handleNotificationTap(data);
            } catch (_) {
              // best-effort: payload may not be query-string; ignore
            }
          }
      });
    } catch (e) {
      developer.log('Local notifications init failed: $e', name: 'NotificationService');
    }
  }

  Future<void> _showLocalNotification(String title, String body, [Map<String, dynamic>? data]) async {
    const android = AndroidNotificationDetails('geges_channel', 'GEGES Notifications', channelDescription: 'General notifications', importance: Importance.max, priority: Priority.high);
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    try {
        // Payload: we serialize a minimal map as query-string key=val pairs so local notification payload remains small
        String? payload;
        if (data != null && data.isNotEmpty) {
          final pairs = <String>[];
          data.forEach((k, v) {
            if (v != null) pairs.add('${Uri.encodeComponent(k)}=${Uri.encodeComponent(v.toString())}');
          });
          payload = pairs.join('&');
        }
        await _local.show(0, title, body, details, payload: payload);
    } catch (e) {
      developer.log('Failed to show local notification: $e', name: 'NotificationService');
    }
  }

  void _startNotificationsListener(String uid) {
    // Listen to notification docs for this user that are not yet delivered
      // Personal notifications
      final subPersonal = _firestore
          .collection('notifications')
          .where('user_id', isEqualTo: uid)
          .where('delivered', isEqualTo: false)
          .snapshots()
          .listen((qs) async {
        for (final doc in qs.docChanges) {
          if (doc.type == DocumentChangeType.added) {
            final data = doc.doc.data();
            if (data == null) continue;
            final title = data['title'] as String? ?? '';
            final body = data['body'] as String? ?? '';
            await _showLocalNotification(title, body, data.cast<String, dynamic>());
            try {
              await doc.doc.reference.update({'delivered': true, 'delivered_at': FieldValue.serverTimestamp()});
            } catch (e) {
              developer.log('Failed to mark notification delivered: $e', name: 'NotificationService');
            }
          }
        }
      }, onError: (e) {
        developer.log('Notifications listener error (personal): $e', name: 'NotificationService');
      });

      _notificationsSubs.add(subPersonal);

      // Broadcast notifications (where 'broadcast' == true)
      final subBroadcast = _firestore
          .collection('notifications')
          .where('broadcast', isEqualTo: true)
          .where('delivered', isEqualTo: false)
          .snapshots()
          .listen((qs) async {
        for (final doc in qs.docChanges) {
          if (doc.type == DocumentChangeType.added) {
            final data = doc.doc.data();
            if (data == null) continue;
            final title = data['title'] as String? ?? '';
            final body = data['body'] as String? ?? '';
            await _showLocalNotification(title, body, data.cast<String, dynamic>());
            try {
              await doc.doc.reference.update({'delivered': true, 'delivered_at': FieldValue.serverTimestamp()});
            } catch (e) {
              developer.log('Failed to mark broadcast notification delivered: $e', name: 'NotificationService');
            }
          }
        }
      }, onError: (e) {
        developer.log('Notifications listener error (broadcast): $e', name: 'NotificationService');
      });

      _notificationsSubs.add(subBroadcast);
  }

  Future<void> _cancelNotificationsListeners() async {
    try {
      for (final s in _notificationsSubs) {
        await s.cancel();
      }
      _notificationsSubs.clear();
    } catch (_) {}
  }
  
  void _handleNotificationTap(Map<String, dynamic> data) {
    // If notification contains queue_id, navigate to BookingDetailScreen
    final qid = data['queue_id'] ?? data['queueId'] ?? data['queueId'.toString()];
    if (qid is String && qid.isNotEmpty) {
      appNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => BookingDetailScreen(queueId: qid)));
    }
  }

  /// Call when user signs out to remove token from Firestore if desired.
  Future<void> removeToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userRef = _firestore.collection('users').doc(uid);
    try {
      await userRef.set({'fcm_token': FieldValue.delete()}, SetOptions(merge: true));
    } catch (e) {
      developer.log('Failed to remove FCM token: $e', name: 'NotificationService');
    }
  }
}
