import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({super.key, required this.postId, this.initialIndex = 0});

  final String postId;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    final media = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('media')
        .orderBy('index')
        .snapshots();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: media,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No images', style: TextStyle(color: Colors.white)));
          }
          final controller = PageController(initialPage: initialIndex.clamp(0, docs.length - 1));
          return PageView.builder(
            controller: controller,
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final b64 = (docs[i].data()['base64'] as String? ?? '');
              if (b64.isEmpty) return const SizedBox.shrink();
              final bytes = base64Decode(b64);
              return Hero(
                tag: 'postImage-${docs.first.reference.parent.parent!.id}-$i',
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


