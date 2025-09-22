import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../services/friend_service.dart';

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final friends = FriendService();
    print('ChatsPage: Building with currentUid: $currentUid');
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/feed')),
        title: const Text('Chats'),
      ),
      body: StreamBuilder<List<String>>(
        stream: friends.mutuals(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final uids = snap.data ?? [];
          print('ChatsPage: Found ${uids.length} mutuals: $uids');
          if (uids.isEmpty) {
            return const Center(child: Text('No mutuals yet. Add friends to start chatting.'));
          }

          return ListView.separated(
            itemCount: uids.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final peerUid = uids[i];
              return _ChatListTile(currentUid: currentUid, peerUid: peerUid);
            },
          );
        },
      ),
    );
  }
}

class _ChatListTile extends StatelessWidget {
  const _ChatListTile({required this.currentUid, required this.peerUid});

  final String currentUid;
  final String peerUid;

  String _roomId() {
    return (currentUid.compareTo(peerUid) < 0)
        ? '${currentUid}_$peerUid'
        : '${peerUid}_$currentUid';
  }

  @override
  Widget build(BuildContext context) {
    final roomId = _roomId();
    final users = FirebaseFirestore.instance.collection('users');
    final rooms = FirebaseFirestore.instance.collection('chats').doc(roomId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: users.doc(peerUid).snapshots(),
      builder: (context, userSnap) {
        final u = userSnap.data?.data();
        final name = (u?['fullName'] ?? u?['username'] ?? peerUid).toString();
        final photo = (u?['photoURL'] ?? '') as String?;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: rooms.collection('messages').orderBy('createdAt', descending: true).limit(1).snapshots(),
            builder: (context, msgSnap) {
              final docs = msgSnap.data?.docs;
              final last = docs?.isNotEmpty == true ? docs!.first.data() : null;
              String preview;
              if (last == null) {
                preview = 'No messages yet';
              } else {
                final String type = (last['type'] ?? 'text').toString();
                final bool sentByMe = last['from'] == currentUid;
                switch (type) {
                  case 'image':
                    preview = sentByMe ? 'You sent a photo' : 'Sent you a photo';
                    break;
                  case 'post':
                    preview = sentByMe ? 'You shared a post' : 'Shared a post with you';
                    break;
                  case 'text':
                  default:
                    final String text = (last['text'] ?? '').toString();
                    preview = sentByMe && text.isNotEmpty ? 'You: $text' : text;
                }
              }
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: _providerFromPhoto(photo),
                child: _providerFromPhoto(photo) == null ? const Icon(Icons.person) : null,
              ),
              title: Text(name),
              subtitle: Text(preview.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => context.push('/chat/$roomId', extra: {
                'currentUid': currentUid,
                'peerUid': peerUid,
                'peerName': name,
                'peerPhoto': photo,
              }),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    await _deleteChat(context, roomId);
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete chat'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> _deleteChat(BuildContext context, String roomId) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final messagesCol = firestore.collection('chats').doc(roomId).collection('messages');

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

    await firestore.collection('chats').doc(roomId).delete().catchError((_) {});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat deleted')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete chat: $e')),
      );
    }
  }
}

ImageProvider<Object>? _providerFromPhoto(String? photo) {
  if (photo == null || photo.isEmpty) return null;
  if (photo.startsWith('data:image')) {
    final base64Part = photo.substring(photo.indexOf(',') + 1);
    try {
      final Uint8List bytes = base64Decode(base64Part);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(photo);
}

// Chat search removed as per request