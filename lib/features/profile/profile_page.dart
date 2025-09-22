import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart' as custom;
import '../../providers/theme_provider.dart';
import '../../services/post_service.dart';
import '../../services/friend_service.dart';
import '../../services/bookmark_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.userId});
  
  final String? userId;

  @override
  Widget build(BuildContext context) {
    return Consumer<custom.AuthProvider>(
        builder: (context, authProvider, child) {
        final firebaseUser = authProvider.firebaseUser;
        final mockUser = authProvider.mockUser;
        final currentUserId = firebaseUser?.uid ?? mockUser?['uid'];
        final profileUserId = userId ?? currentUserId;
          final fallbackDisplayName = firebaseUser?.displayName ?? mockUser?['displayName'] ?? 'User';
          final photoURL = firebaseUser?.photoURL;
          
          if (profileUserId == null) {
          return const Scaffold(body: Center(child: Text('User not found')));
        }

        final isCurrentUser = profileUserId == currentUserId;
        
        return DefaultTabController(
          length: isCurrentUser ? 2 : 1, // Show bookmarks tab only for current user
          child: Scaffold(
            appBar: AppBar(
              title: isCurrentUser 
                ? StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('users').doc(profileUserId).snapshots(),
                    builder: (context, snap) {
                      final fullName = snap.data?.data()?['fullName'] as String?;
                      final displayName = fullName?.isNotEmpty == true ? fullName! : fallbackDisplayName;
                      return Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      );
                    },
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('users').doc(profileUserId).snapshots(),
                          builder: (context, snap) {
                            final fullName = snap.data?.data()?['fullName'] as String?;
                            final displayName = fullName?.isNotEmpty == true ? fullName! : fallbackDisplayName;
                            return Text(
                              displayName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
              actions: [
                if (isCurrentUser) ...[
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return IconButton(
                        onPressed: () => _showThemeDialog(context, themeProvider),
                        icon: Icon(themeProvider.themeIcon),
                        tooltip: 'Theme (${themeProvider.themeModeName})',
                      );
                    },
                  ),
                  IconButton(onPressed: () => _showSignOutDialog(context), icon: const Icon(Icons.menu)),
                ],
              ],
            ),
            body: NestedScrollView(
              headerSliverBuilder: (context, inner) => [
              SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance.collection('users').doc(profileUserId).snapshots(),
                            builder: (context, snap) {
                              final data = snap.data?.data();
                              final firestorePhoto = (data?['photoURL'] as String?) ?? photoURL;
                              final provider = _photoProvider(firestorePhoto);
                              return CircleAvatar(
                                radius: 40,
                                backgroundImage: provider,
                                child: provider == null ? const Icon(Icons.person, size: 40) : null,
                              );
                            },
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                              child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                  _StatNumber(label: 'posts', userId: profileUserId),
                                  _FollowersNumber(label: 'followers', userId: profileUserId),
                                  _FollowingNumber(label: 'following', userId: profileUserId),
                                ],
                            ),
                          ),
                        ],
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('users').doc(profileUserId).snapshots(),
                          builder: (context, snap) {
                            final fullName = snap.data?.data()?['fullName'] as String?;
                            return Text(
                              fullName?.isNotEmpty == true ? fullName! : fallbackDisplayName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('users').doc(profileUserId).snapshots(),
                          builder: (context, snap) {
                            final bio = snap.data?.data()?['bio'] as String?;
                            return Text(
                              bio?.isNotEmpty == true ? bio! : 'DDIT\'27 🎓',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        if (isCurrentUser)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => context.push('/edit-profile'),
                              child: const Text('Edit profile'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  pinned: true,
                  toolbarHeight: 0,
                  bottom: TabBar(
                    tabs: [
                      const Tab(icon: Icon(Icons.grid_on_outlined)),
                      if (isCurrentUser) const Tab(icon: Icon(Icons.bookmark_outline)),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _PostsGrid(userId: profileUserId),
                  if (isCurrentUser) _BookmarksGrid(),
                ],
              ),
                          ),
                        ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        // Add a subtle indicator that this is clickable
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 20,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.grey[400],
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await context.read<custom.AuthProvider>().signOut();
                // Let the router handle the redirect automatically
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                context,
                themeProvider,
                ThemeMode.light,
                Icons.light_mode,
                'Light',
                'Always use light theme',
              ),
              const SizedBox(height: 8),
              _buildThemeOption(
                context,
                themeProvider,
                ThemeMode.dark,
                Icons.dark_mode,
                'Dark',
                'Always use dark theme',
              ),
              const SizedBox(height: 8),
              _buildThemeOption(
                context,
                themeProvider,
                ThemeMode.system,
                Icons.brightness_auto,
                'System',
                'Follow system setting',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider themeProvider,
    ThemeMode mode,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = themeProvider.themeMode == mode;
    
    return InkWell(
      onTap: () {
        themeProvider.setThemeMode(mode);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(color: Theme.of(context).colorScheme.primary)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showFriendsList(BuildContext context, String title, String userId, {bool isFollowers = true}) {
    print('_showFriendsList called with title: $title, userId: $userId, isFollowers: $isFollowers'); // Debug print
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  // Friends list
                  Expanded(
                    child: StreamBuilder<List<String>>(
                      stream: isFollowers ? FriendService().followers() : FriendService().following(),
                      builder: (context, snapshot) {
                        print('Friends stream state: ${snapshot.connectionState}'); // Debug print
                        print('Friends data: ${snapshot.data}'); // Debug print
                        
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final friends = snapshot.data ?? [];
                        if (friends.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.people_outline, size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    isFollowers ? 'No followers yet' : 'Not following anyone yet',
                                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isFollowers 
                                        ? 'When people add you as a friend, they\'ll appear here!'
                                        : 'Add friends to see them here!',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            final friendUid = friends[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[300],
                                child: Text(
                                  friendUid.substring(0, 2).toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              title: Text('User ${friendUid.substring(0, 8)}...'),
                              subtitle: Text(friendUid),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _removeFriend(context, friendUid, isFollowers),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
            );
          },
        );
      },
    );
  }

  void _removeFriend(BuildContext context, String friendUid, bool isFollowers) {
    final action = isFollowers ? 'Remove Follower' : 'Remove Friend';
    final message = isFollowers 
        ? 'Are you sure you want to remove this follower? They will no longer follow you.'
        : 'Are you sure you want to remove this friend? You will no longer follow them.';
        
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(action),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  if (isFollowers) {
                    // Remove from followers (they stop following you)
                    await FriendService().removeFollower(friendUid);
                  } else {
                    // Remove from following (you stop following them)
                    await FriendService().removeFriend(friendUid);
                  }
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$action successful')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to $action: $e')),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(action),
            ),
          ],
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

class _StatNumber extends StatelessWidget {
  const _StatNumber({required this.label, required this.userId});
  final String label;
  final String userId;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: PostService().feedForAuthors([userId]),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return _Stat(label: label, value: count);
      },
    );
  }
}

class _FollowersNumber extends StatelessWidget {
  const _FollowersNumber({required this.label, required this.userId});
  final String label;
  final String userId;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: FriendService().followersForUser(userId),
      builder: (context, snap) {
        final count = snap.data?.length ?? 0;
        return GestureDetector(
          onTap: () {
            print('Navigating to followers for user: $userId');
            context.push('/followers/$userId');
          },
          child: _Stat(label: label, value: count),
        );
      },
    );
  }
}

class _FollowingNumber extends StatelessWidget {
  const _FollowingNumber({required this.label, required this.userId});
  final String label;
  final String userId;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: FriendService().followingForUser(userId),
      builder: (context, snap) {
        final count = snap.data?.length ?? 0;
        return GestureDetector(
          onTap: () {
            print('Navigating to following for user: $userId');
            context.push('/following/$userId');
          },
          child: _Stat(label: label, value: count),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }
}

class _PostsGrid extends StatelessWidget {
  const _PostsGrid({required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: PostService().feedForAuthors([userId]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final query = snapshot.data;
        if (query == null || query.docs.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1.5,
            mainAxisSpacing: 1.5,
          ),
          itemCount: query.docs.length,
          itemBuilder: (context, index) {
            final data = query.docs[index].data();
            final postId = (data['id'] ?? '') as String;
            return _ProfileGridTile(postId: postId);
          },
        );
      },
    );
  }
}

class _ProfileGridTile extends StatelessWidget {
  const _ProfileGridTile({required this.postId});
  final String postId;
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('media')
          .orderBy('index')
          .limit(1)
          .snapshots(),
      builder: (context, mediaSnap) {
        if (!mediaSnap.hasData || mediaSnap.data!.docs.isEmpty) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: const Icon(
              Icons.image_outlined,
              color: Colors.grey,
              size: 32,
            ),
          );
        }
        
        final b64 = (mediaSnap.data!.docs.first.data()['base64'] as String? ?? '');
        if (b64.isEmpty) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: const Icon(
              Icons.image_outlined,
              color: Colors.grey,
              size: 32,
            ),
          );
        }
        
        return GestureDetector(
          onTap: () => context.push('/post/$postId'),
          child: Image.memory(
            base64Decode(b64),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.grey,
                  size: 32,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BookmarksGrid extends StatelessWidget {
  const _BookmarksGrid();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: BookmarkService().getBookmarkedPostsWithDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final bookmarkedPosts = snapshot.data ?? [];
        
        if (bookmarkedPosts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No bookmarks yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the bookmark icon on posts to save them here',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1.5,
            mainAxisSpacing: 1.5,
          ),
          itemCount: bookmarkedPosts.length,
          itemBuilder: (context, index) {
            final bookmarkData = bookmarkedPosts[index];
            final postId = bookmarkData['postId'] as String;
            return _BookmarkGridTile(postId: postId);
          },
        );
      },
    );
  }
}

class _BookmarkGridTile extends StatelessWidget {
  const _BookmarkGridTile({required this.postId});
  final String postId;
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('media')
          .orderBy('index')
          .limit(1)
          .snapshots(),
      builder: (context, mediaSnap) {
        if (!mediaSnap.hasData || mediaSnap.data!.docs.isEmpty) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: const Icon(
              Icons.image_outlined,
              color: Colors.grey,
              size: 32,
            ),
          );
        }
        
        final b64 = (mediaSnap.data!.docs.first.data()['base64'] as String? ?? '');
        if (b64.isEmpty) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: const Icon(
              Icons.image_outlined,
              color: Colors.grey,
              size: 32,
            ),
          );
        }
        
        return GestureDetector(
          onTap: () => context.push('/post/$postId'),
          child: Image.memory(
            base64Decode(b64),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.grey,
                  size: 32,
                ),
              );
            },
          ),
        );
      },
    );
  }
}


