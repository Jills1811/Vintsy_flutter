import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookmarkService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the current user's UID
  String? get _currentUid => _auth.currentUser?.uid;

  /// Check if a post is bookmarked by the current user
  Future<bool> isBookmarked(String postId) async {
    if (_currentUid == null) return false;
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_currentUid)
          .collection('bookmarks')
          .doc(postId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking bookmark status: $e');
      return false;
    }
  }

  /// Stream to listen to bookmark status changes
  Stream<bool> isBookmarkedStream(String postId) {
    if (_currentUid == null) return Stream.value(false);
    
    return _firestore
        .collection('users')
        .doc(_currentUid)
        .collection('bookmarks')
        .doc(postId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Bookmark a post
  Future<void> bookmarkPost(String postId) async {
    if (_currentUid == null) throw Exception('User not authenticated');
    
    try {
      await _firestore
          .collection('users')
          .doc(_currentUid)
          .collection('bookmarks')
          .doc(postId)
          .set({
        'postId': postId,
        'bookmarkedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error bookmarking post: $e');
      rethrow;
    }
  }

  /// Remove bookmark from a post
  Future<void> unbookmarkPost(String postId) async {
    if (_currentUid == null) throw Exception('User not authenticated');
    
    try {
      await _firestore
          .collection('users')
          .doc(_currentUid)
          .collection('bookmarks')
          .doc(postId)
          .delete();
    } catch (e) {
      print('Error unbookmarking post: $e');
      rethrow;
    }
  }

  /// Toggle bookmark status
  Future<void> toggleBookmark(String postId) async {
    final isBookmarked = await this.isBookmarked(postId);
    if (isBookmarked) {
      await unbookmarkPost(postId);
    } else {
      await bookmarkPost(postId);
    }
  }

  /// Get all bookmarked posts for the current user
  Stream<QuerySnapshot<Map<String, dynamic>>> getBookmarkedPosts() {
    if (_currentUid == null) return Stream.empty();
    
    return _firestore
        .collection('users')
        .doc(_currentUid)
        .collection('bookmarks')
        .orderBy('bookmarkedAt', descending: true)
        .snapshots();
  }

  /// Get bookmarked posts with post details
  Stream<List<Map<String, dynamic>>> getBookmarkedPostsWithDetails() {
    if (_currentUid == null) return Stream.value([]);
    
    return _firestore
        .collection('users')
        .doc(_currentUid)
        .collection('bookmarks')
        .orderBy('bookmarkedAt', descending: true)
        .snapshots()
        .asyncMap((bookmarkSnap) async {
      final List<Map<String, dynamic>> posts = [];
      
      for (final bookmarkDoc in bookmarkSnap.docs) {
        final postId = bookmarkDoc.data()['postId'] as String;
        
        try {
          // Get the post details
          final postDoc = await _firestore
              .collection('posts')
              .doc(postId)
              .get();
          
          if (postDoc.exists) {
            final postData = postDoc.data()!;
            posts.add({
              'postId': postId,
              'bookmarkData': bookmarkDoc.data(),
              'postData': postData,
            });
          }
        } catch (e) {
          print('Error fetching bookmarked post $postId: $e');
          // Continue with other posts even if one fails
        }
      }
      
      return posts;
    });
  }

  /// Get bookmark count for a post
  Stream<int> getBookmarkCount(String postId) {
    return _firestore
        .collectionGroup('bookmarks')
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
