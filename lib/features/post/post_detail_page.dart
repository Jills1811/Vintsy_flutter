import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../services/post_service.dart';
import '../../services/bookmark_service.dart';
import '../../services/friend_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  @override
  Widget build(BuildContext context) {
    final service = PostService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          Builder(builder: (context) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: service.streamPost(widget.postId),
        builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
          final data = snap.data!.data();
                if (data == null) return const SizedBox.shrink();
          final String authorUid = (data['authorUid'] ?? '') as String? ?? '';
                  final myUid = FirebaseAuth.instance.currentUser?.uid;
                  final isMine = myUid != null && myUid == authorUid;
                
                  if (!isMine) return const SizedBox.shrink();
                
                  return IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete post',
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete post?'),
                          content: const Text('This cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        try {
                          await PostService().deletePost(widget.postId);
                          if (!mounted) return;
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted')));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                        }
                      }
                  },
                );
                    },
                  );
                }),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: service.streamPost(widget.postId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data();
          if (data == null) return const Center(child: Text('Post not found'));
          
          final String authorUid = (data['authorUid'] ?? '') as String? ?? '';
          final String? caption = data['caption'] as String?;
          final String? location = data['locationName'] as String?;
          final int imageCount = (data['mediaCount'] as int?) ?? 0;
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

          return SingleChildScrollView(
            child: Column(
              children: [
                // Post card using feed UI style
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Author header
                      _buildAuthorHeader(context, authorUid, createdAt),
                      
                      // Post content
                      GestureDetector(
                        onTap: () => context.push('/viewer', extra: {'postId': widget.postId, 'index': 0}),
                        child: Container(
                          width: double.infinity,
                          height: 300,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildPostContent(context, widget.postId, imageCount),
                        ),
                      ),
                      
                      // Post actions
                      _buildPostActions(context, widget.postId, authorUid),
                      
                      // Caption
                      if (caption != null && caption.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            caption,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      
                      // Location
                      if (location != null && location.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                location,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
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
      ),
    );
  }

  Widget _buildCommentsList(BuildContext context, String postId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final comments = snapshot.data?.docs ?? [];
        
        if (comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                      children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
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
              ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
                                      backgroundImage: _photoProvider(photo),
                                      child: _photoProvider(photo) == null ? const Icon(Icons.person) : null,
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(commenterUid).snapshots(),
      builder: (context, snap) {
        final userData = snap.data?.data();
        final displayName = userData?['fullName'] as String? ?? 'User';
        final photoURL = userData?['photoURL'] as String?;
        
        return ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundImage: _photoProvider(photoURL),
            child: _photoProvider(photoURL) == null ? const Icon(Icons.person, size: 16) : null,
          ),
          title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text),
              const SizedBox(height: 4),
              Text(
                _formatTimeAgo(createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          dense: true,
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
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
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    }
  }
}
