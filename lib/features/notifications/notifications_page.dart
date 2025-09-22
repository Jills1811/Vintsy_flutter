import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final Set<String> _selectedNotifications = <String>{};
  bool _isSelectionMode = false;
  bool _autoMarkedOnce = false;

  @override
  void initState() {
    super.initState();
    // Best-effort mark all as read when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      try {
        await NotificationService().markAllRead(uid);
      } catch (_) {
        // ignore; UI still loads, and user can tap Mark all read
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final service = NotificationService();
    
    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode 
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedNotifications.clear();
                  });
                },
              )
            : BackButton(onPressed: () => Navigator.of(context).maybePop()),
        title: Text(_isSelectionMode 
            ? '${_selectedNotifications.length} selected'
            : 'Notifications'),
        actions: _isSelectionMode
            ? [
                if (_selectedNotifications.isNotEmpty)
                  TextButton(
                    onPressed: () => _deleteSelectedNotifications(),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
              ]
            : [
                TextButton(
                  onPressed: () => service.markAllRead(uid),
                  child: const Text('Mark all read'),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'select_all') {
                      setState(() => _isSelectionMode = true);
                    } else if (value == 'delete_all') {
                      _deleteAllNotifications();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'select_all',
                      child: Text('Select notifications'),
                    ),
                    const PopupMenuItem(
                      value: 'delete_all',
                      child: Text('Delete all', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.notifications(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.warning_amber, size: 40, color: Colors.orange),
                    SizedBox(height: 12),
                    Text('Unable to load notifications.'),
                    SizedBox(height: 8),
                    Text('Please check Firestore rules for notifications access.'),
                  ],
                ),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          // Client-side dedupe as a safeguard (by type+fromUid+postId)
          final seenKeys = <String>{};
          final docs = snap.data!.docs.where((d) {
            final n = d.data();
            final type = (n['type'] ?? '').toString();
            final fromUid = (n['fromUid'] ?? '').toString();
            final postId = (n['postId'] ?? '').toString();
            final key = type + '|' + fromUid + '|' + postId;
            if (seenKeys.contains(key)) return false;
            seenKeys.add(key);
            return true;
          }).toList();
          if (docs.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }
          // Auto-mark visible unread notifications on first load
          if (!_autoMarkedOnce) {
            final unread = docs.where((d) => (d.data()['read'] ?? false) == false).toList();
            if (unread.isNotEmpty) {
              _autoMarkedOnce = true;
              // Fire-and-forget best-effort marking
              Future.microtask(() async {
                try {
                  final batch = FirebaseFirestore.instance.batch();
                  for (final d in unread) {
                    batch.update(d.reference, {'read': true});
                  }
                  await batch.commit();
                } catch (_) {}
              });
            }
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final doc = docs[i];
              final n = doc.data();
              final notificationId = doc.id;
              final type = (n['type'] ?? '').toString();
              final fromUid = (n['fromUid'] ?? '').toString();
              final read = (n['read'] ?? false) == true;
              final isSelected = _selectedNotifications.contains(notificationId);
              
              return _NotificationTile(
                notificationId: notificationId,
                type: type,
                fromUid: fromUid,
                read: read,
                isSelected: isSelected,
                isSelectionMode: _isSelectionMode,
                onTap: () {
                  if (_isSelectionMode) {
                    setState(() {
                      if (isSelected) {
                        _selectedNotifications.remove(notificationId);
                      } else {
                        _selectedNotifications.add(notificationId);
                      }
                    });
                  }
                },
                onDelete: () => _deleteNotification(notificationId),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notification: $e')),
        );
      }
    }
  }

  Future<void> _deleteSelectedNotifications() async {
    if (_selectedNotifications.isEmpty) return;
    
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final batch = FirebaseFirestore.instance.batch();
      
      for (final notificationId in _selectedNotifications) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(notificationId);
        batch.delete(docRef);
      }
      
      await batch.commit();
      
      setState(() {
        _selectedNotifications.clear();
        _isSelectionMode = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedNotifications.length} notifications deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notifications: $e')),
        );
      }
    }
  }

  Future<void> _deleteAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Notifications'),
        content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete all notifications: $e')),
        );
      }
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notificationId,
    required this.type,
    required this.fromUid,
    required this.read,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onDelete,
  });

  final String notificationId;
  final String type;
  final String fromUid;
  final bool read;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(fromUid).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final displayName = userData?['fullName'] as String? ?? 'User';
        final photoURL = userData?['photoURL'] as String?;
        
        String title;
        String subtitle;
        IconData icon;
        Color? iconColor;
        
        if (type == NotificationType.follow.name) {
          title = '$displayName started following you';
          subtitle = 'Tap to view profile';
          icon = Icons.person_add;
        } else if (type == NotificationType.comment.name) {
          title = '$displayName commented on your post';
          subtitle = 'Tap to view post';
          icon = Icons.mode_comment_outlined;
        } else if (type == NotificationType.like.name) {
          title = '$displayName liked your post';
          subtitle = 'Tap to view post';
          icon = Icons.favorite;
          iconColor = Colors.pink;
        } else {
          title = 'Activity from $displayName';
          subtitle = 'Tap to view';
          icon = Icons.notifications;
        }

        return Container(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
          child: ListTile(
            leading: isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                  )
                : CircleAvatar(
                    radius: 20,
                    backgroundImage: _photoProvider(photoURL),
                    child: _photoProvider(photoURL) == null ? const Icon(Icons.person, size: 20) : null,
                  ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: read ? FontWeight.normal : FontWeight.w600,
              ),
            ),
            subtitle: Text(subtitle),
            trailing: isSelectionMode
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!read)
                        const Icon(Icons.circle, size: 10, color: Colors.blue),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            onDelete();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
            onTap: onTap,
            onLongPress: isSelectionMode ? null : () {
              // Show context menu for individual notification
              showModalBottomSheet(
                context: context,
                builder: (ctx) => Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: const Text('Delete notification'),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onDelete();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
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
