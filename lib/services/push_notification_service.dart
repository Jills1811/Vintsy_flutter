import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize push notifications
  static Future<void> initialize() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('User granted permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted push notification permission');
        
        // Get FCM token
        String? token = await _messaging.getToken();
        print('FCM Token: $token');
        
        // Save token to Firestore for current user
        await _saveTokenToFirestore(token);
        
        // Set up message handlers
        await _setupMessageHandlers();
        
        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_saveTokenToFirestore);
      } else {
        print('User declined or has not accepted permission');
      }
    } catch (e) {
      print('Error initializing push notifications: $e');
    }
  }

  // Save FCM token to Firestore
  static Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null || _auth.currentUser == null) return;

    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      print('FCM token saved to Firestore');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Set up message handlers
  static Future<void> _setupMessageHandlers() async {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showLocalNotification(message);
      }
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      _handleNotificationTap(message);
    });

    // Handle notification taps when app is terminated
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('App opened from terminated state via notification');
      _handleNotificationTap(initialMessage);
    }
  }

  // Show local notification when app is in foreground
  static void _showLocalNotification(RemoteMessage message) {
    // You can use flutter_local_notifications package for more control
    // For now, we'll just print the notification
    print('Local notification: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
  }

  // Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    
    // Navigate to appropriate screen based on notification data
    String? type = message.data['type'];
    String? targetId = message.data['targetId'];
    
    switch (type) {
      case 'like':
        // Navigate to post
        if (targetId != null) {
          // Use your router to navigate to post
          print('Navigate to post: $targetId');
        }
        break;
      case 'comment':
        // Navigate to post
        if (targetId != null) {
          print('Navigate to post: $targetId');
        }
        break;
      case 'follow':
        // Navigate to profile
        if (targetId != null) {
          print('Navigate to profile: $targetId');
        }
        break;
      default:
        // Navigate to notifications page
        print('Navigate to notifications page');
    }
  }

  // Send notification to a specific user
  static Future<void> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String body,
    required String type,
    String? targetId,
    Map<String, String>? data,
  }) async {
    try {
      // Get target user's FCM token
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(targetUserId)
          .get();
      
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      String? fcmToken = userData?['fcmToken'] as String?;
      
      if (fcmToken == null) {
        print('No FCM token found for user: $targetUserId');
        return;
      }

      // Prepare notification data
      Map<String, String> notificationData = {
        'type': type,
        'targetId': targetId ?? '',
        'fromUserId': _auth.currentUser?.uid ?? '',
        'fromUserName': _auth.currentUser?.displayName ?? 'Someone',
        ...?data,
      };

      // Send notification via Firestore (you can also use Firebase Admin SDK)
      await _firestore.collection('notifications').add({
        'toUserId': targetUserId,
        'fromUserId': _auth.currentUser?.uid,
        'title': title,
        'body': body,
        'type': type,
        'targetId': targetId,
        'data': notificationData,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'fcmToken': fcmToken,
      });

      print('Notification sent to user: $targetUserId');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send notification to multiple users
  static Future<void> sendNotificationToUsers({
    required List<String> targetUserIds,
    required String title,
    required String body,
    required String type,
    String? targetId,
    Map<String, String>? data,
  }) async {
    for (String userId in targetUserIds) {
      await sendNotificationToUser(
        targetUserId: userId,
        title: title,
        body: body,
        type: type,
        targetId: targetId,
        data: data,
      );
    }
  }

  // Get FCM token
  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  // Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  // Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
  print('Message data: ${message.data}');
  print('Message notification: ${message.notification?.title}');
}
