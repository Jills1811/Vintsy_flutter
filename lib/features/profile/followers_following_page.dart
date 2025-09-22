import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../services/friend_service.dart';

class FollowersFollowingPage extends StatefulWidget {
  const FollowersFollowingPage({
    super.key,
    required this.type,
    required this.userId,
  });

  final String type; // 'followers' or 'following'
  final String userId;

  @override
  State<FollowersFollowingPage> createState() => _FollowersFollowingPageState();
}

class _FollowersFollowingPageState extends State<FollowersFollowingPage> {
  final FriendService _friendService = FriendService();

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = FirebaseAuth.instance.currentUser?.uid == widget.userId;
    final title = widget.type == 'followers' ? 'Followers' : 'Following';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: StreamBuilder<List<String>>(
        stream: widget.type == 'followers' 
            ? _friendService.followersForUser(widget.userId) 
            : _friendService.followingForUser(widget.userId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final userIds = snap.data!;
          if (userIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.type == 'followers' ? Icons.people_outline : Icons.person_add_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.type == 'followers' 
                        ? 'No followers yet' 
                        : 'Not following anyone',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: userIds.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final uid = userIds[index];
              return _UserTile(
                userId: uid,
                type: widget.type,
                isCurrentUser: isCurrentUser,
                onUnfollow: () => _handleUnfollow(uid),
                onRemoveFollower: () => _handleRemoveFollower(uid),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleUnfollow(String targetUserId) async {
    try {
      await _friendService.removeFriend(targetUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unfollowed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unfollow: $e')),
        );
      }
    }
  }

  Future<void> _handleRemoveFollower(String targetUserId) async {
    try {
      await _friendService.removeFollower(targetUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follower removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove follower: $e')),
        );
      }
    }
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.userId,
    required this.type,
    required this.isCurrentUser,
    required this.onUnfollow,
    required this.onRemoveFollower,
  });

  final String userId;
  final String type;
  final bool isCurrentUser;
  final VoidCallback onUnfollow;
  final VoidCallback onRemoveFollower;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        final userData = snap.data?.data();
        final displayName = userData?['fullName'] as String? ?? 'User';
        final photoURL = userData?['photoURL'] as String?;
        
        return GestureDetector(
          onTap: () {
            // Navigate to the user's profile
            context.push('/profile/$userId');
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: _photoProvider(photoURL),
                child: _photoProvider(photoURL) == null ? const Icon(Icons.person, size: 24) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '@${userId.substring(0, 8)}...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrentUser) ...[
                if (type == 'following')
                  TextButton(
                    onPressed: () => _showUnfollowDialog(context),
                    child: const Text('Unfollow'),
                  )
                else
                  TextButton(
                    onPressed: () => _showRemoveFollowerDialog(context),
                    child: const Text('Remove'),
                  ),
              ],
            ],
          ),
          ),
        );
      },
    );
  }

  void _showUnfollowDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unfollow'),
        content: const Text('Are you sure you want to unfollow this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onUnfollow();
            },
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );
  }

  void _showRemoveFollowerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Follower'),
        content: const Text('Are you sure you want to remove this follower?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onRemoveFollower();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
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
