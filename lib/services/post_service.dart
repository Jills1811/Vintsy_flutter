import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'notification_service.dart';

class PostService {
  PostService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  String get _uid => _auth.currentUser!.uid;

  Future<void> createPost({
    required List<File> files,
    String? caption,
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    final postRef = _firestore.collection('posts').doc();

    await postRef.set({
      'id': postRef.id,
      'authorUid': _uid,
      'type': 'image',
      'caption': caption,
      'location': locationName,
      'geo': (latitude != null && longitude != null)
          ? {'lat': latitude, 'lng': longitude}
          : null,
      'shareCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'mediaCount': files.length,
    });

    final mediaCol = postRef.collection('media');
    for (int i = 0; i < files.length; i++) {
      // Read and compress image to keep well under Firestore 1MB doc limit
      final originalBytes = await files[i].readAsBytes();
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) continue;
      final resized = img.copyResize(decoded, width: 720);
      final jpgBytes = img.encodeJpg(resized, quality: 60);
      final encoded = base64Encode(jpgBytes);
      await mediaCol.add({
        'index': i,
        'base64': encoded,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> feedForAuthors(List<String> authorUids) {
    if (authorUids.isEmpty) {
      return _firestore.collection('posts').where('authorUid', isEqualTo: '_none_').snapshots();
    }
    return _firestore
        .collection('posts')
        .where('authorUid', whereIn: authorUids.length > 10 ? authorUids.sublist(0, 10) : authorUids)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamPost(String postId) {
    return _firestore.collection('posts').doc(postId).snapshots();
  }

  Future<void> addComment({
    required String postId, 
    required String text,
    String? parentCommentId,
  }) async {
    final commentsRef = _firestore.collection('posts').doc(postId).collection('comments').doc();
    await commentsRef.set({
      'id': commentsRef.id,
      'authorUid': _uid,
      'text': text,
      'parentCommentId': parentCommentId, // null for top-level comments
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notify post author about the new comment (only for top-level comments)
    if (parentCommentId == null) {
      try {
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        final authorUid = (postDoc.data()?['authorUid'] ?? '') as String?;
        if (authorUid != null && authorUid.isNotEmpty && authorUid != _uid) {
          await NotificationService(firestore: _firestore).addCommentNotification(
            toUserUid: authorUid,
            commenterUid: _uid,
            postId: postId,
            commentText: text,
          );
        }
      } catch (_) {
        // ignore notification failures
      }
    } else {
      // Notify the parent comment author about the reply
      try {
        final parentCommentDoc = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(parentCommentId)
            .get();
        final parentAuthorUid = (parentCommentDoc.data()?['authorUid'] ?? '') as String?;
        if (parentAuthorUid != null && parentAuthorUid.isNotEmpty && parentAuthorUid != _uid) {
          await NotificationService(firestore: _firestore).addReplyNotification(
            toUserUid: parentAuthorUid,
            replierUid: _uid,
            postId: postId,
            commentId: parentCommentId,
            replyText: text,
          );
        }
      } catch (_) {
        // ignore notification failures
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> commentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> incrementShare(String postId) async {
    final postDoc = _firestore.collection('posts').doc(postId);
    await postDoc.update({'shareCount': FieldValue.increment(1)});
  }

  // Likes
  CollectionReference<Map<String, dynamic>> _likesCol(String postId) =>
      _firestore.collection('posts').doc(postId).collection('likes');

  Stream<bool> isLikedByMe(String postId) {
    final uid = _uid;
    return _likesCol(postId).doc(uid).snapshots().map((d) => d.exists);
  }

  Stream<int> likeCount(String postId) {
    return _likesCol(postId).snapshots().map((s) => s.size);
  }

  Future<void> toggleLike(String postId) async {
    final uid = _uid;
    final likeRef = _likesCol(postId).doc(uid);
    bool isNowLiked = false;
    await _firestore.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      if (likeSnap.exists) {
        tx.delete(likeRef);
      } else {
        tx.set(likeRef, {'since': FieldValue.serverTimestamp()});
        isNowLiked = true;
      }
    });

    // Send like notification to author (best-effort)
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final authorUid = (postDoc.data()?['authorUid'] ?? '') as String?;
      if (authorUid != null && authorUid.isNotEmpty && authorUid != _uid) {
        final notif = NotificationService(firestore: _firestore);
        if (isNowLiked) {
          await notif.addLikeNotification(
            toUserUid: authorUid,
            likerUid: _uid,
            postId: postId,
          );
        } else {
          await notif.removeLikeNotification(
            toUserUid: authorUid,
            likerUid: _uid,
            postId: postId,
          );
        }
      }
    } catch (_) {}
  }

  // Share a post to multiple peers by dropping a message into each chat
  Future<void> sharePostToUsers(String postId, List<String> peerUids) async {
    if (peerUids.isEmpty) return;
    final String currentUid = _uid;
    final WriteBatch batch = _firestore.batch();

    for (final peerUid in peerUids) {
      final roomId = (currentUid.compareTo(peerUid) < 0)
          ? '${currentUid}_${peerUid}'
          : '${peerUid}_${currentUid}';
      final msgRef = _firestore
          .collection('chats')
          .doc(roomId)
          .collection('messages')
          .doc();
      batch.set(msgRef, {
        'id': msgRef.id,
        'from': currentUid,
        'to': peerUid,
        'type': 'post',
        'postId': postId,
        'text': 'Shared a post',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // commit messages first; do not include post update to avoid rule failures
    await batch.commit();

    // best-effort aggregate shareCount on the post (may fail for non-author)
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      await postRef.update({'shareCount': FieldValue.increment(peerUids.length)});
    } catch (_) {
      // ignore if not allowed by rules; messages were already sent
    }
  }

  // Delete a post and all of its nested data. Only author should be allowed by rules.
  Future<void> deletePost(String postId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final postSnap = await postRef.get();
    if (!postSnap.exists) return;
    final String authorUid = (postSnap.data()?['authorUid'] ?? '') as String? ?? '';
    if (authorUid != _uid) {
      throw Exception('Only the author can delete this post');
    }

    // Delete subcollections in batches to avoid timeouts
    Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> col,
        {int batchSize = 200}) async {
      Query<Map<String, dynamic>> query = col.limit(batchSize);
      while (true) {
        final snap = await query.get();
        if (snap.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        if (snap.docs.length < batchSize) break;
      }
    }

    // Delete media, likes, comments subcollections
    await _deleteCollection(postRef.collection('media'));
    await _deleteCollection(postRef.collection('likes'));
    await _deleteCollection(postRef.collection('comments'));

    // Finally delete post doc
    await postRef.delete();
  }
}


