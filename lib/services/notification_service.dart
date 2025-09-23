import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'push_notification_service.dart';

enum NotificationType { like, comment, follow, reply }

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _userNotifs(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  Future<void> addFollowNotification({
    required String toUserUid,
    required String followerUid,
  }) async {
    // Use deterministic ID to avoid duplicate follow notifications
    final docId = 'follow_' + followerUid;
    final ref = _userNotifs(toUserUid).doc(docId);
    
    print('NotificationService: Creating follow notification for $toUserUid from $followerUid');
    
    // Always create/update with fresh timestamp for immediate visibility
    await ref.set({
      'type': NotificationType.follow.name,
      'fromUid': followerUid,
      'toUid': toUserUid,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
    
    // Send push notification
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await PushNotificationService.sendNotificationToUser(
        targetUserId: toUserUid,
        title: 'New Follower',
        body: '${currentUser.displayName ?? 'Someone'} started following you',
        type: 'follow',
        targetId: followerUid,
      );
    }
    
    print('NotificationService: Follow notification created successfully');
  }

  Future<void> addCommentNotification({
    required String toUserUid,
    required String commenterUid,
    required String postId,
    required String commentText,
  }) async {
    await _userNotifs(toUserUid).add({
      'type': NotificationType.comment.name,
      'fromUid': commenterUid,
      'toUid': toUserUid,
      'postId': postId,
      'commentText': commentText,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    // Send push notification
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await PushNotificationService.sendNotificationToUser(
        targetUserId: toUserUid,
        title: 'New Comment',
        body: '${currentUser.displayName ?? 'Someone'} commented on your post',
        type: 'comment',
        targetId: postId,
      );
    }
  }

  Future<void> addLikeNotification({
    required String toUserUid,
    required String likerUid,
    required String postId,
  }) async {
    // Deterministic ID: one like notification per (post, liker)
    final docId = 'like_' + postId + '_' + likerUid;
    final ref = _userNotifs(toUserUid).doc(docId);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update({'read': false});
    } else {
      await ref.set({
        'type': NotificationType.like.name,
        'fromUid': likerUid,
        'toUid': toUserUid,
        'postId': postId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Send push notification only for new likes
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await PushNotificationService.sendNotificationToUser(
          targetUserId: toUserUid,
          title: 'New Like',
          body: '${currentUser.displayName ?? 'Someone'} liked your post',
          type: 'like',
          targetId: postId,
        );
      }
    }
  }

  Future<void> addReplyNotification({
    required String toUserUid,
    required String replierUid,
    required String postId,
    required String commentId,
    required String replyText,
  }) async {
    await _userNotifs(toUserUid).add({
      'type': NotificationType.reply.name,
      'fromUid': replierUid,
      'toUid': toUserUid,
      'postId': postId,
      'commentId': commentId,
      'replyText': replyText,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    // Send push notification
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await PushNotificationService.sendNotificationToUser(
        targetUserId: toUserUid,
        title: 'New Reply',
        body: '${currentUser.displayName ?? 'Someone'} replied to your comment',
        type: 'reply',
        targetId: postId,
        data: {'commentId': commentId},
      );
    }
  }

  Future<void> removeLikeNotification({
    required String toUserUid,
    required String likerUid,
    required String postId,
  }) async {
    final docId = 'like_' + postId + '_' + likerUid;
    await _userNotifs(toUserUid).doc(docId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notifications(String uid) {
    return _userNotifs(uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> markAllRead(String uid) async {
    final batch = _db.batch();
    final snap = await _userNotifs(uid).where('read', isEqualTo: false).get();
    for (final d in snap.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }
}


