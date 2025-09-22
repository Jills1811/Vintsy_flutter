import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/friend_service.dart';

class AddFriendQrPage extends StatefulWidget {
  const AddFriendQrPage({super.key});

  @override
  State<AddFriendQrPage> createState() => _AddFriendQrPageState();
}

class _AddFriendQrPageState extends State<AddFriendQrPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _manualController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: [BarcodeFormat.qrCode],
  );
  bool _isProcessingScan = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manualController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  String _buildQrPayload(String uid) => 'vintsy:uid:$uid';

  String? _extractUidFromPayload(String raw) {
    if (raw.startsWith('vintsy:uid:')) return raw.substring('vintsy:uid:'.length);
    // fallback: allow plain UID pasted/scanned
    if (raw.length >= 8) return raw; // crude check
    return null;
  }

  Future<void> _handleUidAdd(String uid) async {
    try {
      await FriendService().addFriend(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend added')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    final codes = capture.barcodes.map((b) => b.rawValue).whereType<String>().toList();
    if (codes.isEmpty) return;
    final maybeUid = _extractUidFromPayload(codes.first);
    if (maybeUid == null) return;
    _isProcessingScan = true;
    await _handleUidAdd(maybeUid);
    _isProcessingScan = false;
  }

  Future<void> _pickImageAndScan() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    try {
      final capture = await _scannerController.analyzeImage(x.path);
      if (capture == null || capture.barcodes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No QR code found in image')));
        return;
      }
      final codes = capture.barcodes.map((b) => b.rawValue).whereType<String>().toList();
      if (codes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No QR code found in image')));
        return;
      }
      final maybeUid = _extractUidFromPayload(codes.first);
      if (maybeUid == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid QR payload')));
        return;
      }
      await _handleUidAdd(maybeUid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to scan image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Friend'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My QR'),
            Tab(text: 'Scan'),
            Tab(text: 'Gallery'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My QR
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        QrImageView(
                          data: _buildQrPayload(uid),
                          version: QrVersions.auto,
                          size: 200,
                        ),
                        const SizedBox(height: 12),
                        SelectableText(uid, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: uid));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UID copied')));
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy UID'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Add by UID (manual)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _manualController,
                  decoration: const InputDecoration(
                    labelText: 'Friend UID or QR payload',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    final raw = _manualController.text.trim();
                    final maybeUid = _extractUidFromPayload(raw);
                    if (maybeUid != null) {
                      _handleUidAdd(maybeUid);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid UID/QR payload')));
                    }
                  },
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add Friend'),
                ),
                const SizedBox(height: 16), // Extra padding at bottom for keyboard
              ],
            ),
          ),

          // Scan with camera
          Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => _scannerController.toggleTorch(),
                      icon: const Icon(Icons.flash_on),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _scannerController.switchCamera(),
                      icon: const Icon(Icons.cameraswitch),
                    ),
                  ],
                ),
              )
            ],
          ),

          // Pick from gallery
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Scan QR from an image'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _pickImageAndScan,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose Image'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


