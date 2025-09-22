import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/post_service.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> with TickerProviderStateMixin {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<XFile> _pickedFiles = [];
  bool _isUploading = false;
  int _currentImageIndex = 0;
  late PageController _pageController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isNotEmpty) {
      setState(() {
        _pickedFiles = files;
        _currentImageIndex = 0;
      });
      _fadeController.forward();
    }
  }

  Future<void> _pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file != null) {
      setState(() {
        _pickedFiles = [file];
        _currentImageIndex = 0;
      });
      _fadeController.forward();
    }
  }

  void _removeImage(int index) {
    setState(() {
      _pickedFiles.removeAt(index);
      if (_currentImageIndex >= _pickedFiles.length) {
        _currentImageIndex = _pickedFiles.length - 1;
      }
      if (_pickedFiles.isEmpty) {
        _fadeController.reverse();
      }
    });
  }

  Future<void> _share() async {
    if (_pickedFiles.isEmpty) {
      _showErrorSnackBar('Please select at least one image');
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
      
      _showSuccessSnackBar('Post shared successfully!');
      context.go('/feed');
    } catch (e) {
      _showErrorSnackBar('Failed to share post: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Post', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _share,
            child: Text(
              'Share',
              style: TextStyle(
                color: _isUploading
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.38)
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Image Preview Section
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              child: _pickedFiles.isEmpty
                  ? _buildImagePickerPlaceholder()
                  : _buildImagePreview(),
            ),
          ),
          
          // Content Section
          Expanded(
            flex: 2,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Caption Section
                    _buildCaptionSection(),
                    const SizedBox(height: 20),
                    
                    // Location Section
                    _buildLocationSection(),
                    const SizedBox(height: 20),
                    
                    // Upload Progress
                    if (_isUploading) _buildUploadProgress(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: null,
            ),
          ),
          const SizedBox(height: 16),
          Text('Add Photos',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 8),
          Text('Choose from your gallery or take a photo',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 14,
              )),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: _pickImages,
              ),
              const SizedBox(width: 20),
              _buildActionButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: _pickFromCamera,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        // Image Carousel
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentImageIndex = index);
          },
          itemCount: _pickedFiles.length,
          itemBuilder: (context, index) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Image.file(
                File(_pickedFiles[index].path),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            );
          },
        ),
        
        // Image Counter
        if (_pickedFiles.length > 1)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${_pickedFiles.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        
        // Remove Image Button
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: () => _removeImage(_currentImageIndex),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        
        // Add More Button
        Positioned(
          bottom: 16,
          right: 16,
          child: GestureDetector(
            onTap: _pickImages,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Caption',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
          ),
          child: TextField(
            controller: _captionController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Write a caption...',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
            maxLines: 4,
            maxLength: 2200,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
          ),
          child: TextField(
            controller: _locationController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Add location...',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
              prefixIcon: Icon(Icons.location_on_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(width: 12),
          Text('Sharing your post...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              )),
        ],
      ),
    );
  }
}
