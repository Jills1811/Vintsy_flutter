import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/friend_service.dart';
import '../../services/post_service.dart';
import '../../services/bookmark_service.dart';
 
import 'dart:convert';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    final friendService = FriendService();
    
    
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: const [
            SizedBox(width: 16),
            Text('Vintsy', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _unreadNotificationsStream(),
            builder: (context, snap) {
              final hasUnread = (snap.data?.docs.isNotEmpty ?? false);
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite_outline),
                    onPressed: () {
                      // Navigate immediately; mark-as-read is best-effort
                      context.push('/notifications');
                      // Fire-and-forget to avoid blocking navigation
                      // ignore: unawaited_futures
                      _markAllNotificationsRead();
                    },
                  ),
                  if (hasUnread)
                    const Positioned(
                      right: 12,
                      top: 12,
                      child: _RedDot(),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined),
            onPressed: () {
              print('FeedPage: Send icon tapped, navigating to /chats');
              context.push('/chats');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<String>>(
          stream: friendService.mutuals(),
          builder: (context, mutualsSnap) {
            if (mutualsSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
            
          final currentUid = auth.currentUser?.uid;
            final mutuals = mutualsSnap.data ?? [];
            print('FeedPage: Current user UID: $currentUid');
            print('FeedPage: Mutual friends: $mutuals');
            
            final authorUids = <String>{...mutuals};
          if (currentUid != null) authorUids.add(currentUid);
            print('FeedPage: Author UIDs for feed: $authorUids');
            print('FeedPage: Author UIDs list: ${authorUids.toList()}');

            return _buildPostsSection(context, authorUids);
          },
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _unreadNotificationsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream<QuerySnapshot>.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .limit(1)
        .snapshots();
  }

  Future<void> _markAllNotificationsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false);
    final snap = await col.get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  // Stories removed

  Widget _buildPostsSection(BuildContext context, Set<String> authorUids) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('authorUid', whereIn: authorUids.length > 10 ? authorUids.take(10).toList() : authorUids.toList())
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        print('FeedPage: Total posts: ${docs.length}');

        // Filter posts to only show from mutual friends or current user
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final authorUid = data['authorUid'] as String?;
          final isFromMutual = authorUids.contains(authorUid);
          print('FeedPage: Post from $authorUid, isFromMutual: $isFromMutual');
          return isFromMutual;
        }).toList();

        print('FeedPage: Filtered posts: ${filteredDocs.length}');

        if (filteredDocs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_camera_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Share your first post!',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final postId = doc.id;
            final authorUid = data['authorUid'] as String? ?? '';
            final caption = data['caption'] as String? ?? '';
            final location = data['location'] as String? ?? '';
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final imageCount = data['imageCount'] as int? ?? 0;

            return _buildPostCard(context, postId, authorUid, caption, location, createdAt, imageCount);
          },
        );
      },
    );
  }

  Widget _buildPostCard(BuildContext context, String postId, String authorUid, String caption, String location, DateTime createdAt, int imageCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          _buildAuthorHeader(context, authorUid, createdAt),
          
          // Post content
          GestureDetector(
          onTap: () => context.push('/viewer', extra: {'postId': postId, 'index': 0}),
            child: Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildPostContent(context, postId, imageCount),
            ),
          ),
          
          // Post actions
          _buildPostActions(context, postId, authorUid),
          
          // Caption
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                caption,
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAuthorHeader(BuildContext context, String authorUid, DateTime createdAt) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(authorUid)
                .snapshots(),
            builder: (context, snap) {
              final userData = snap.data?.data();
              final displayName = userData?['fullName'] as String? ?? 'User';
              final photoURL = userData?['photoURL'] as String?;
              
              return Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: _photoProvider(photoURL),
                      child: _photoProvider(photoURL) == null ? const Icon(Icons.person, size: 16) : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Spacer(),
          Text(
            _formatTimeAgo(createdAt),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(BuildContext context, String postId, int imageCount) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('media')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No images'));
        }

        final firstMedia = docs.first.data() as Map<String, dynamic>;
        final base64Data = firstMedia['base64'] as String?;
        if (base64Data == null || base64Data.isEmpty) {
          return const Center(child: Text('No image data'));
        }

        try {
          final bytes = base64Decode(base64Data);
          return Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {
          return const Center(child: Text('Invalid image data'));
        }
      },
    );
  }

  Widget _buildPostActions(BuildContext context, String postId, String authorUid) {
    final postService = PostService();
    return Row(
      children: [
        StreamBuilder<bool>(
          stream: postService.isLikedByMe(postId),
          builder: (context, snap) {
            final liked = snap.data ?? false;
            return IconButton(
              icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? Colors.red : null),
              onPressed: () async {
                try {
                  await postService.toggleLike(postId);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to like: $e')),
                    );
                  }
                }
              },
            );
          },
        ),
        StreamBuilder<int>(
          stream: postService.likeCount(postId),
          builder: (context, snap) {
            final count = snap.data ?? 0;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(count.toString()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.mode_comment_outlined),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _CommentModal(postId: postId, authorUid: authorUid),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.send_outlined),
          onPressed: () {
            _showShareModal(context, postId);
          },
        ),
        const Spacer(),
        StreamBuilder<bool>(
          stream: BookmarkService().isBookmarkedStream(postId),
          builder: (context, snap) {
            final isBookmarked = snap.data ?? false;
            return IconButton(
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: isBookmarked ? Colors.blue : null,
              ),
              onPressed: () async {
                try {
                  await BookmarkService().toggleBookmark(postId);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to bookmark: $e')),
                    );
                  }
                }
              },
            );
          },
        ),
      ],
    );
  }

  void _showShareModal(BuildContext context, String postId) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final friendService = FriendService();
        final Set<String> selected = <String>{};

        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Share to',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<String>>(
                      stream: friendService.mutuals(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          );
                        }
                        final mutualUids = snap.data!;
                        if (mutualUids.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No mutual friends yet'),
                          );
                        }

                        // Limit whereIn to <=10 per Firestore constraint
                        final List<String> limitedUids = mutualUids.length > 10
                            ? mutualUids.take(10).toList()
                            : mutualUids;

                        final usersStream = FirebaseFirestore.instance
                            .collection('users')
                            .where(FieldPath.documentId, whereIn: limitedUids)
                            .snapshots();

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: usersStream,
                          builder: (context, usersSnap) {
                            if (!usersSnap.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              );
                            }
                            final docs = usersSnap.data!.docs;

                            return SizedBox(
                              height: 420,
                              child: ListView.builder(
                                itemCount: docs.length,
                                itemBuilder: (context, i) {
                                  final data = docs[i].data();
                                  final uid = docs[i].id;
                                  final name = data['fullName'] as String? ?? 'User';
                                  final photo = data['photoURL'] as String?;
                                  final isSelected = selected.contains(uid);
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: (photo != null && photo.isNotEmpty)
                                          ? NetworkImage(photo)
                                          : null,
                                      child: (photo == null || photo.isEmpty)
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    trailing: Checkbox(
                                      value: isSelected,
                                      onChanged: (_) {
                                        setState(() {
                                          if (isSelected) {
                                            selected.remove(uid);
                                          } else {
                                            selected.add(uid);
                                          }
                                        });
                                      },
                                    ),
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          selected.remove(uid);
                                        } else {
                                          selected.add(uid);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: selected.isEmpty
                                  ? null
                                  : () async {
                                      await _shareToSelected(context, postId, selected.toList());
                                      if (context.mounted) Navigator.of(context).pop();
                                    },
                              icon: const Icon(Icons.send),
                              label: Text(selected.isEmpty ? 'Send' : 'Send to ${selected.length}'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _shareToSelected(BuildContext context, String postId, List<String> toUids) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final peerUid in toUids) {
      final roomId = _getRoomId(currentUid, peerUid);
      final msgRef = FirebaseFirestore.instance
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
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Optional: upsert chat metadata
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(roomId);
      batch.set(chatRef, {
        'users': [currentUid, peerUid],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageType': 'post',
        'lastMessagePostId': postId,
      }, SetOptions(merge: true));
    }
    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post shared')),
      );
    }
  }

  String _getRoomId(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}_${pair[1]}';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _RedDot extends StatelessWidget {
  const _RedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CommentModal extends StatefulWidget {
  const _CommentModal({
    required this.postId,
    required this.authorUid,
  });

  final String postId;
  final String authorUid;

  @override
  State<_CommentModal> createState() => _CommentModalState();
}

class _CommentModalState extends State<_CommentModal> {
  final TextEditingController _commentController = TextEditingController();
  final PostService _postService = PostService();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return GestureDetector(
            onTap: () {}, // Prevent tap from bubbling up
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Comments list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(widget.postId)
                      .collection('comments')
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final comments = snapshot.data?.docs ?? [];
                    
                    if (comments.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            Text(
                              'Be the first to comment!',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final data = comment.data() as Map<String, dynamic>;
                        final commenterUid = data['authorUid'] as String? ?? '';
                        final text = data['text'] as String? ?? '';
                        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                        
                        return _CommentTile(
                          commenterUid: commenterUid,
                          text: text,
                          createdAt: createdAt,
                        );
                      },
                    );
                  },
                ),
              ),
              
              const Divider(height: 1),
              
              // Comment input
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addComment,
                      icon: const Icon(Icons.send),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      await _postService.addComment(postId: widget.postId, text: text);
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.commenterUid,
    required this.text,
    required this.createdAt,
  });

  final String commenterUid;
  final String text;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    if (commenterUid.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(commenterUid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data();
        final displayName = userData?['fullName'] as String? ?? 'User';
        final photoURL = userData?['photoURL'] as String?;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: _photoProvider(photoURL),
                child: _photoProvider(photoURL) == null ? const Icon(Icons.person, size: 16) : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$displayName ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          TextSpan(
                            text: text,
                            style: const TextStyle(color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimeAgo(createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}

class _ShareModal extends StatefulWidget {
  const _ShareModal({
    required this.postId,
  });

  final String postId;

  @override
  State<_ShareModal> createState() => _ShareModalState();
}

class _ShareModalState extends State<_ShareModal> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedFriends = <String>{};
  final FriendService _friendService = FriendService();
  final PostService _postService = PostService();
  bool _isSharing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return GestureDetector(
            onTap: () {}, // Prevent tap from bubbling up
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text(
                          'Share',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedFriends.isNotEmpty)
                          TextButton(
                            onPressed: _isSharing ? null : _shareToSelectedFriends,
                            child: _isSharing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    'Send (${_selectedFriends.length})',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1),
                  
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search friends...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {}); // Trigger rebuild for search
                      },
                    ),
                  ),
                  
                  // Quick actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildQuickAction(
                          icon: Icons.auto_stories,
                          label: 'Add to Story',
                          onTap: () {
                            // TODO: Implement share to story
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Share to story coming soon!'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1),
                  
                  // Friends list
                  Expanded(
                    child: StreamBuilder<List<String>>(
                      stream: _friendService.mutuals(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }

                        final mutuals = snapshot.data ?? [];
                        if (mutuals.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No mutual friends',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                                Text(
                                  'Follow more people to share posts!',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }

                        // Filter friends based on search
                        final searchQuery = _searchController.text.toLowerCase();
                        final filteredMutuals = mutuals.where((uid) {
                          // For now, we'll show all friends since we don't have names in the list
                          // In a real app, you'd filter by display name
                          return true;
                        }).toList();

                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filteredMutuals.length,
                itemBuilder: (context, index) {
                            final friendUid = filteredMutuals[index];
                            return _ShareFriendTile(
                              friendUid: friendUid,
                              postId: widget.postId,
                              isSelected: _selectedFriends.contains(friendUid),
                              onSelectionChanged: (isSelected) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedFriends.add(friendUid);
                                  } else {
                                    _selectedFriends.remove(friendUid);
                                  }
                                });
                              },
                  );
                },
              );
            },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareToSelectedFriends() async {
    if (_selectedFriends.isEmpty || _isSharing) return;

    setState(() => _isSharing = true);

    try {
      await _postService.sharePostToUsers(widget.postId, _selectedFriends.toList());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post shared with ${_selectedFriends.length} friend(s)!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }
}

class _ShareFriendTile extends StatefulWidget {
  const _ShareFriendTile({
    required this.friendUid,
    required this.postId,
    required this.isSelected,
    required this.onSelectionChanged,
  });

  final String friendUid;
  final String postId;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;

  @override
  State<_ShareFriendTile> createState() => _ShareFriendTileState();
}

class _ShareFriendTileState extends State<_ShareFriendTile> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.friendUid)
          .snapshots(),
      builder: (context, snap) {
        final userData = snap.data?.data();
        final displayName = userData?['fullName'] as String? ?? 'User';
        final photoURL = userData?['photoURL'] as String?;
        
        return InkWell(
          onTap: () => widget.onSelectionChanged(!widget.isSelected),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: photoURL != null && photoURL.isNotEmpty
                      ? NetworkImage(photoURL)
                      : null,
                  child: (photoURL == null || photoURL.isEmpty)
                      ? const Icon(Icons.person, size: 24)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Active now',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isSelected ? Colors.blue : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: widget.isSelected ? Colors.blue : Colors.transparent,
                  ),
                  child: widget.isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

ImageProvider<Object>? _photoProvider(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('data:image')) {
    try {
      final base64Part = value.substring(value.indexOf(',') + 1);
      return MemoryImage(base64Decode(base64Part));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(value);
}