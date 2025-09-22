import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../features/splash/splash_page.dart';
import '../features/auth/sign_in_page.dart';
import '../features/auth/sign_up_page.dart';
import '../features/feed/feed_page.dart';
import '../features/post/post_page.dart';
import '../features/post/create_post_page.dart';
 
import '../features/profile/profile_page.dart';
import '../features/friends/add_friend_qr_page.dart';
import '../providers/auth_provider.dart';
import '../features/main_layout/main_layout.dart';
import '../features/post/post_detail_page.dart';
import '../features/chats/chats_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/post/image_viewer_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../features/profile/followers_following_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'dart:math';

// Global navigator key for router
final navigatorKey = GlobalKey<NavigatorState>();

/// Listenable that notifies GoRouter when the auth stream changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  static final router = GoRouter(
    navigatorKey: navigatorKey,
    refreshListenable:
        GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuthenticated = FirebaseAuth.instance.currentUser != null;
      final isAuthRoute = state.matchedLocation == '/signin' || 
                         state.matchedLocation == '/signup';
      final isSplashRoute = state.matchedLocation == '/splash';

      // If on splash, redirect based on auth state
      if (isSplashRoute) {
        return isAuthenticated ? '/feed' : '/signin';
      }

      // If user is not authenticated and not on auth route, redirect to signin
      if (!isAuthenticated && !isAuthRoute) {
        return '/signin';
      }

      // If user is authenticated and on auth route, redirect to feed
      if (isAuthenticated && isAuthRoute) {
        return '/feed';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpPage(),
      ),
      // Shell route for main app with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, state) => const FeedPage(),
          ),
          GoRoute(
            path: '/chats',
            builder: (context, state) => const ChatsPage(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/scanner',
            builder: (context, state) => const AddFriendQrPage(),
          ),
          GoRoute(
            path: '/post',
            builder: (context, state) => const CreatePostPage(),
          ),
          GoRoute(
            path: '/post/:postId',
            builder: (context, state) => PostDetailPage(postId: state.pathParameters['postId']!),
          ),
          GoRoute(
            path: '/viewer',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return ImageViewerPage(
                postId: (extra?['postId'] ?? '') as String,
                initialIndex: (extra?['index'] ?? 0) as int,
              );
            },
          ),
 
          GoRoute(
            path: '/chat/:roomId',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return _ChatRoomPage(
                roomId: state.pathParameters['roomId']!,
                currentUid: extra?['currentUid'] ?? '',
                peerUid: extra?['peerUid'] ?? '',
                peerName: extra?['peerName'] ?? '',
                peerPhoto: extra?['peerPhoto'],
              );
            },
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/profile/:userId',
            builder: (context, state) => ProfilePage(userId: state.pathParameters['userId']!),
          ),
          GoRoute(
            path: '/followers/:userId',
            builder: (context, state) => FollowersFollowingPage(
              type: 'followers',
              userId: state.pathParameters['userId']!,
            ),
          ),
          GoRoute(
            path: '/following/:userId',
            builder: (context, state) => FollowersFollowingPage(
              type: 'following',
              userId: state.pathParameters['userId']!,
            ),
          ),
        ],
      ),
      // Routes outside shell (no bottom navigation)
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfilePage(),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundPage(),
  );
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Route not found')),
    );
  }
}

class _ChatRoomPage extends StatefulWidget {
  const _ChatRoomPage({
    required this.roomId,
    required this.currentUid,
    required this.peerUid,
    required this.peerName,
    required this.peerPhoto,
  });
  
  final String roomId;
  final String currentUid;
  final String peerUid;
  final String peerName;
  final String? peerPhoto;

  @override
  State<_ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<_ChatRoomPage> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final ref = FirebaseFirestore.instance.collection('chats').doc(widget.roomId).collection('messages').doc();
    await ref.set({
      'id': ref.id,
      'from': widget.currentUid,
      'to': widget.peerUid,
      'text': text,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });
    _controller.clear();
  }

  Future<void> _unsendMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.roomId)
          .collection('messages')
          .doc(messageId)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message unsent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unsend message: $e')),
        );
      }
    }
  }

  Future<void> _sendImage({required ImageSource source}) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1440);
      if (picked == null) return;
      setState(() => _sending = true);

      // Read, resize, and compress to keep below Firestore document limits
      final bytes = await File(picked.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Failed to decode image');
      final resized = img.copyResize(decoded, width: 720);
      final jpgBytes = img.encodeJpg(resized, quality: 60);
      final base64Str = base64Encode(jpgBytes);

      final msgRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.roomId)
          .collection('messages')
          .doc();
      await msgRef.set({
        'id': msgRef.id,
        'from': widget.currentUid,
        'to': widget.peerUid,
        'type': 'image',
        'imageBase64': base64Str,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteChat() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final messagesCol = firestore.collection('chats').doc(widget.roomId).collection('messages');

      const int batchSize = 200;
      while (true) {
        final snap = await messagesCol.limit(batchSize).get();
        if (snap.docs.isEmpty) break;
        final batch = firestore.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        if (snap.docs.length < batchSize) break;
      }

      await firestore.collection('chats').doc(widget.roomId).delete().catchError((_) {});

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgs = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: _photoProvider(widget.peerPhoto),
              child: _photoProvider(widget.peerPhoto) == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.peerName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete chat'),
                    content: const Text('This will delete the whole chat for both users. Continue?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _deleteChat();
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem<String>(value: 'delete', child: Text('Delete chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: msgs,
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    reverse: true,
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final m = docs[i].data();
                      final isMe = m['from'] == widget.currentUid;
                      final createdAt = (m['createdAt'] as Timestamp?)?.toDate();
                      return _ChatMessage(
                        message: m,
                        isMe: isMe,
                        currentUid: widget.currentUid,
                        onUnsend: isMe ? () => _unsendMessage(m['id']) : null,
                        createdAt: createdAt,
                      );
                    },
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Message... ',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Gallery',
                    icon: const Icon(Icons.photo_library_outlined),
                    onPressed: () => _sendImage(source: ImageSource.gallery),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _ChatMessage extends StatelessWidget {
  const _ChatMessage({
    required this.message,
    required this.isMe,
    required this.currentUid,
    this.onUnsend,
    this.createdAt,
  });

  final Map<String, dynamic> message;
  final bool isMe;
  final String currentUid;
  final VoidCallback? onUnsend;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final messageType = message['type'] as String? ?? 'text';
    final text = message['text'] as String? ?? '';
    final postId = message['postId'] as String?;
    final imageBase64 = message['imageBase64'] as String?;

    final bubbleColor = isMe 
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surface;
    final textColor = isMe 
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: onUnsend != null ? () => _showUnsendDialog(context) : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isMe ? bubbleColor : bubbleColor.withOpacity(0.08),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: messageType == 'post' && postId != null
                      ? _PostMessageWidget(postId: postId, isMe: isMe)
                      : (messageType == 'image' && imageBase64 != null)
                          ? _ImageMessageWidgetBase64(imageBase64: imageBase64)
                      : DefaultTextStyle(
                          style: TextStyle(color: textColor),
                          child: _TextMessageWidget(text: text, isMe: isMe),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(context, createdAt),
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime? time) {
    if (time == null) return '';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }

  void _showUnsendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsend Message'),
        content: const Text('Are you sure you want to unsend this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onUnsend?.call();
            },
            child: const Text('Unsend', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _TextMessageWidget extends StatelessWidget {
  const _TextMessageWidget({
    required this.text,
    required this.isMe,
  });

  final String text;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1) 
            : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(text)),
          if (isMe) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.undo,
              size: 12,
              color: Colors.grey[600],
            ),
          ],
        ],
      ),
    );
  }
}

class _PostMessageWidget extends StatelessWidget {
  const _PostMessageWidget({
    required this.postId,
    required this.isMe,
  });

  final String postId;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('posts').doc(postId).snapshots(),
      builder: (context, postSnap) {
        if (!postSnap.hasData) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1) 
                  : Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Loading post...'),
          );
        }

        final postData = postSnap.data!.data();
        if (postData == null) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1) 
                  : Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Post not found'),
          );
        }

        final caption = postData['caption'] as String? ?? '';
        final location = postData['locationName'] as String?;
        final authorUid = postData['authorUid'] as String?;

        return Container(
          decoration: BoxDecoration(
            color: isMe 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1) 
                : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post images
              _PostImages(postId: postId),
              
              // Post content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author info
                    if (authorUid != null)
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance.collection('users').doc(authorUid).snapshots(),
                        builder: (context, authorSnap) {
                          final authorData = authorSnap.data?.data();
                          final authorName = authorData?['fullName'] as String? ?? 'User';
                          final authorPhoto = authorData?['photoURL'] as String?;
                          
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundImage: _photoProvider(authorPhoto),
                                child: _photoProvider(authorPhoto) == null ? const Icon(Icons.person, size: 12) : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                authorName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          );
                        },
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Caption
                    if (caption.isNotEmpty)
                      Text(caption, style: const TextStyle(fontSize: 14)),
                    
                    // Location
                    if (location != null && location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14),
                          const SizedBox(width: 4),
                          Text(location, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                    
                    // Unsend indicator for own messages
                    if (isMe) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.undo,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PostImages extends StatelessWidget {
  const _PostImages({required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('media')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Center(child: Text('No images')),
          );
        }

        // Show first image for chat preview
        final firstImage = docs.first.data()['base64'] as String?;
        if (firstImage == null) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Center(child: Text('No image data')),
          );
        }

        return GestureDetector(
          onTap: () => context.push('/viewer', extra: {'postId': postId, 'index': 0}),
          child: Container(
            height: 200,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.memory(
                base64Decode(firstImage),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ImageMessageWidgetBase64 extends StatelessWidget {
  const _ImageMessageWidgetBase64({required this.imageBase64});

  final String imageBase64;

  Future<void> _saveToGallery(BuildContext context) async {
    try {
      final Uint8List bytes = base64Decode(imageBase64);
      final tmp = await Directory.systemTemp.createTemp('vintsy_');
      final file = File('${tmp.path}/image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path, mimeType: 'image/jpeg')]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = base64Decode(imageBase64);
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Image.memory(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[300],
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => _saveToGallery(context),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.download_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        )
      ],
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
