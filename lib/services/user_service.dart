import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  UserService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get currentUid => _auth.currentUser!.uid;

  Future<void> ensureProfile({required String fullName}) async {
    final doc = _firestore.collection('users').doc(currentUid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'fullName': fullName,
        'email': _auth.currentUser!.email,
        'photoURL': _auth.currentUser!.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    return snap.data();
  }
}


