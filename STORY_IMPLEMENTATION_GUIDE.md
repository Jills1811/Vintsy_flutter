# Instagram-Like Stories Implementation Guide

## Overview
This guide shows how to implement Instagram-like stories in your Flutter app using free video hosting services and Firestore for metadata.

## 🎯 Features Implemented
- ✅ Story creation with video upload
- ✅ Story viewer with auto-play
- ✅ 24-hour expiry system
- ✅ Story metadata in Firestore
- ✅ Mutual friends story feed
- ✅ Professional UI/UX

## 📁 File Structure
```
lib/
├── models/
│   └── story_model.dart          # Story data model
├── services/
│   └── story_service.dart        # Story operations
└── features/stories/
    ├── stories_page.dart         # Stories list/feed
    ├── create_story_page.dart    # Story creation UI
    └── story_viewer_page.dart    # Story viewer with video player
```

## 🗄️ Firestore Document Structure

### Stories Collection
```javascript
// Collection: stories
// Document ID: auto-generated
{
  "id": "story_123",
  "authorUid": "user_456",
  "videoUrl": "https://github.com/username/repo/raw/main/videos/story.mp4",
  "thumbnailUrl": "https://github.com/username/repo/raw/main/thumbnails/story.jpg", // optional
  "caption": "Check out this amazing sunset! 🌅", // optional
  "createdAt": "2024-01-15T10:30:00Z",
  "expiresAt": "2024-01-16T10:30:00Z", // 24 hours later
  "isViewed": false
}
```

### Firestore Queries

#### Get Active Stories from Mutual Friends
```dart
Stream<List<StoryModel>> getStoriesFromMutuals(List<String> mutualUids) {
  final now = Timestamp.now();
  
  return _firestore
      .collection('stories')
      .where('authorUid', whereIn: mutualUids)
      .where('expiresAt', isGreaterThan: now)
      .orderBy('expiresAt')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => StoryModel.fromFirestore(doc))
        .where((story) => !story.isExpired)
        .toList();
  });
}
```

## 🆓 Free Video Hosting Options

### 1. GitHub (Recommended)
**Pros:** Free, reliable, easy to use
**Cons:** 100MB file limit, public repositories

#### Setup Steps:
1. Create a GitHub repository
2. Upload videos to a `videos/` folder
3. Get raw URLs: `https://github.com/username/repo/raw/main/videos/story.mp4`

#### Implementation:
```dart
Future<String> uploadToGitHub(File videoFile) async {
  // Use GitHub API to upload file
  // Return the raw URL
  final rawUrl = 'https://github.com/username/repo/raw/main/videos/${videoFile.path.split('/').last}';
  return rawUrl;
}
```

### 2. Google Drive
**Pros:** 15GB free storage, private files
**Cons:** Requires API setup, rate limits

#### Setup Steps:
1. Create Google Cloud Project
2. Enable Drive API
3. Create service account
4. Share folder with service account

#### Implementation:
```dart
Future<String> uploadToGoogleDrive(File videoFile) async {
  // Use Google Drive API
  // Return the public sharing URL
  return 'https://drive.google.com/uc?id=FILE_ID';
}
```

### 3. Netlify
**Pros:** Free tier, easy deployment
**Cons:** Requires build process

#### Setup Steps:
1. Create Netlify site
2. Upload videos to `public/videos/` folder
3. Deploy and get URLs

#### Implementation:
```dart
Future<String> uploadToNetlify(File videoFile) async {
  // Upload to Netlify
  // Return the public URL
  return 'https://yoursite.netlify.app/videos/story.mp4';
}
```

## 🎬 Video Player Implementation

### Dependencies
```yaml
dependencies:
  video_player: ^2.8.1
```

### Usage
```dart
class StoryViewerPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return VideoPlayerController.networkUrl(
      Uri.parse(story.videoUrl),
    );
  }
}
```

## ⏰ 24-Hour Expiry System

### Automatic Cleanup
```dart
Future<void> cleanupExpiredStories() async {
  final expiredStories = await _firestore
      .collection('stories')
      .where('expiresAt', isLessThan: Timestamp.now())
      .get();
  
  final batch = _firestore.batch();
  for (final doc in expiredStories.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
}
```

### Client-Side Filtering
```dart
bool get isExpired => DateTime.now().isAfter(expiresAt);

// Filter out expired stories
final activeStories = stories.where((story) => !story.isExpired).toList();
```

## 🎨 UI/UX Features

### Story Creation
- Video picker (gallery/camera)
- Caption input
- Upload progress
- Professional dark theme

### Story Viewer
- Full-screen video player
- Progress bars for multiple stories
- Tap to pause/play
- Swipe navigation
- Auto-advance after 5 seconds

### Stories Feed
- Author avatars with unviewed indicators
- Time remaining display
- Grouped by author
- Blue border for unviewed stories

## 🚀 Getting Started

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Add Routes
```dart
// In router.dart
GoRoute(
  path: '/stories',
  builder: (context, state) => const StoriesPage(),
),
GoRoute(
  path: '/create-story',
  builder: (context, state) => const CreateStoryPage(),
),
```

### 3. Update Navigation
```dart
// Add stories tab to bottom navigation
BottomNavigationBarItem(
  icon: Icon(Icons.auto_stories_outlined),
  activeIcon: Icon(Icons.auto_stories),
  label: 'Stories',
),
```

### 4. Implement Video Upload
Replace the placeholder upload function in `create_story_page.dart` with your chosen hosting service.

## 🔧 Customization Options

### Video Duration
```dart
// Limit video length
maxDuration: const Duration(seconds: 15),
```

### Story Expiry
```dart
// Change expiry time
final expiresAt = now.add(const Duration(hours: 24));
```

### Auto-advance Timing
```dart
// Change story duration
duration: const Duration(seconds: 5),
```

## 📱 Testing

### Test Story Creation
1. Navigate to stories tab
2. Tap + button
3. Select/record video
4. Add caption
5. Share story

### Test Story Viewing
1. Tap on story author
2. Watch video auto-play
3. Swipe to next story
4. Verify 24-hour expiry

## 🎯 Next Steps

1. **Implement actual video upload** to your chosen hosting service
2. **Add story analytics** (views, engagement)
3. **Implement story reactions** (hearts, emojis)
4. **Add story highlights** (save to profile)
5. **Implement story sharing** to other users

## 🐛 Troubleshooting

### Video Not Playing
- Check video URL is accessible
- Verify video format (MP4 recommended)
- Check network connectivity

### Stories Not Loading
- Verify Firestore rules allow read access
- Check mutual friends are properly loaded
- Ensure stories haven't expired

### Upload Failures
- Check file size limits
- Verify hosting service credentials
- Check network connectivity

## 📚 Additional Resources

- [Flutter Video Player Documentation](https://pub.dev/packages/video_player)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [GitHub API Documentation](https://docs.github.com/en/rest)
- [Google Drive API Documentation](https://developers.google.com/drive/api)

---

**Note:** This implementation provides a solid foundation for Instagram-like stories. Customize the video hosting solution based on your specific needs and requirements.
