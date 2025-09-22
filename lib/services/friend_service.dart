import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  FriendService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String? get _uidOrNull => _auth.currentUser?.uid;

  /// Adds friendUid to current user's following list (one-way relationship)
  /// This only affects the "following" count, not "followers"
  Future<void> addFriend(String friendUid) async {
    final uid = _uidOrNull;
    if (uid == null) return;
    // Add to current user's following list
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(friendUid)
        .set({'since': FieldValue.serverTimestamp()});
    
    // Add current user to friend's followers list
    await _firestore
        .collection('users')
        .doc(friendUid)
        .collection('followers')
        .doc(uid)
        .set({'since': FieldValue.serverTimestamp()});

    // Notify the user that they have a new follower
    try {
      await NotificationService(firestore: _firestore).addFollowNotification(
        toUserUid: friendUid,
        followerUid: uid,
      );
      print('FriendService: Follow notification sent to $friendUid from $uid');
    } catch (e) {
      print('FriendService: Failed to send follow notification: $e');
      // Don't fail the entire follow operation if notification fails
    }
  }

  /// Gets all friend UIDs (both following and followers combined)
  Stream<List<String>> friendUids() async* {
    final followingList = await following().first;
    final followersList = await followers().first;
    final allFriends = <String>{};
    allFriends.addAll(followingList);
    allFriends.addAll(followersList);
    yield allFriends.toList();
  }

  /// Gets users who are following the current user (they added you as friend)
  Stream<List<String>> followers() {
    final uid = _uidOrNull;
    if (uid == null) return Stream.value(<String>[]);
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  /// Gets users who the current user is following (you added them as friend)
  Stream<List<String>> following() {
    final uid = _uidOrNull;
    if (uid == null) return Stream.value(<String>[]);
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  /// Gets users who are following a specific user
  Stream<List<String>> followersForUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  /// Gets users who a specific user is following
  Stream<List<String>> followingForUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  /// Stream of mutual follower UIDs (both following each other)
  Stream<List<String>> mutuals() {
    final uid = _uidOrNull;
    if (uid == null) return Stream.value(<String>[]);
    final Stream<List<String>> followingStream = following();
    final Stream<List<String>> followersStream = followers();

    return Stream<List<String>>.multi((controller) {
      List<String>? latestFollowing;
      List<String>? latestFollowers;

      void emitIfReady() {
        if (latestFollowing != null && latestFollowers != null) {
          final mutual = latestFollowing!
              .toSet()
              .intersection(latestFollowers!.toSet())
              .toList();
          print('FriendService.mutuals: following=' + latestFollowing!.toString() + ', followers=' + latestFollowers!.toString());
          print('FriendService.mutuals: mutual=' + mutual.toString());
          controller.add(mutual);
        }
      }

      final sub1 = followingStream.listen((v) {
        latestFollowing = v;
        emitIfReady();
      }, onError: controller.addError);

      final sub2 = followersStream.listen((v) {
        latestFollowers = v;
        emitIfReady();
      }, onError: controller.addError);

      controller.onCancel = () async {
        await sub1.cancel();
        await sub2.cancel();
      };
    });
  }

  /// Removes friendUid from current user's following list ONLY
  /// This does NOT affect followers - they remain following you
  Future<void> removeFriend(String friendUid) async {
    final uid = _uidOrNull;
    if (uid == null) return;
    // Remove from current user's following list
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(friendUid)
        .delete();
    
    // Remove current user from friend's followers list
    await _firestore
        .collection('users')
        .doc(friendUid)
        .collection('followers')
        .doc(uid)
        .delete();
  }

  /// Removes someone from your followers (they stop following you)
  /// This is separate from removing them from your following
  Future<void> removeFollower(String followerUid) async {
    final uid = _uidOrNull;
    if (uid == null) return;
    // Remove from current user's followers list
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('followers')
        .doc(followerUid)
        .delete();
    
    // Remove current user from their following list
    await _firestore
        .collection('users')
        .doc(followerUid)
        .collection('following')
        .doc(uid)
        .delete();
  }
}
