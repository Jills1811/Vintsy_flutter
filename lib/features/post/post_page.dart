import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/post_service.dart';

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<XFile> _pickedFiles = [];
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 40);
    if (files.isNotEmpty) {
      setState(() => _pickedFiles = files);
    }
  }

  Future<void> _share() async {
    if (_pickedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick at least one image')));
      return;
    }
    setState(() => _isUploading = true);
    try {
      await PostService().createPost(
        files: _pickedFiles.map((x) => File(x.path)).toList(),
        caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
        locationName: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post shared')));
      context.go('/feed');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: _pickedFiles.isEmpty
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48),
                          SizedBox(height: 8),
                          Text('Tap to pick images')
                        ],
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (_, i) => AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_pickedFiles[i].path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: _pickedFiles.length,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isUploading ? null : _share,
              icon: _isUploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.share_outlined),
              label: const Text('Share'),
            )
          ],
          ),
        ),
      ),
    );
  }
}


