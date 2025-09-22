import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google (for existing users only)
  Future<UserCredential> signInWithGoogle() async {
    try {
      print('Google Sign-In: Starting Google Sign-In flow...');
      
      // Force sign out from Google Sign-In to show account picker
      await _googleSignIn.signOut();
      print('Google Sign-In: Signed out from Google Sign-In to show account picker');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google Sign-In: User cancelled the sign-in');
        throw Exception('Google sign in was cancelled');
      }

      print('Google Sign-In: Google user obtained: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('Google Sign-In: Google authentication obtained');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      print('Google Sign-In: Signing in to Firebase...');
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      final userUid = userCredential.user!.uid;
      final userEmail = userCredential.user!.email;
      
      print('Google Sign-In: User UID: $userUid, Email: $userEmail');

      // Check if user profile exists in Firestore by EMAIL
      print('Google Sign-In: Checking if user profile exists in Firestore...');
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();
      
      print('Google Sign-In: Firestore query result - Found ${emailQuery.docs.length} documents');
      
      if (emailQuery.docs.isEmpty) {
        // User profile doesn't exist - sign them out and throw error
        print('Google Sign-In: Profile not found by email, signing out user');
        await _auth.signOut();
        throw Exception('Account not found. Please sign up first using email/password or Google sign-up.');
      }

      // User profile exists - allow sign-in
      print('Google Sign-In: Profile found by email, allowing sign-in');
      return userCredential;
      
    } catch (e) {
      print('Google Sign-In error: $e');
      throw _handleAuthException(e);
    }
  }

  // Sign up with Google (creates new user profile only)
  Future<void> signUpWithGoogle() async {
    try {
      print('Google Sign-Up: Starting Google Sign-In flow...');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google Sign-Up: User cancelled the sign-in');
        throw Exception('Google sign up was cancelled');
      }

      print('Google Sign-Up: Google user obtained: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('Google Sign-Up: Google authentication obtained');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential temporarily
      print('Google Sign-Up: Signing in to Firebase temporarily...');
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      final userUid = userCredential.user!.uid;
      final userEmail = userCredential.user!.email;
      final displayName = userCredential.user!.displayName ?? 'Google User';
      
      print('Google Sign-Up: User UID: $userUid, Email: $userEmail, Display Name: $displayName');

      // Check if user profile already exists
      print('Google Sign-Up: Checking if user profile exists in Firestore...');
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();
      
      print('Google Sign-Up: Firestore query result - Found ${emailQuery.docs.length} documents');
      
      if (emailQuery.docs.isNotEmpty) {
        // User already exists - throw error for sign-up
        print('Google Sign-Up: User already exists, cannot sign up');
        await _auth.signOut();
        throw Exception('An account with this email already exists. Please sign in instead.');
      }

      // Create new user profile in Firestore (only for new users)
      print('Google Sign-Up: Creating new user profile in Firestore...');
      try {
        await _firestore.collection('users').doc(userUid).set({
          'fullName': displayName,
          'email': userEmail,
          'createdAt': FieldValue.serverTimestamp(),
          'photoURL': userCredential.user!.photoURL,
          'provider': 'google',
        });
        print('Google Sign-Up: New user profile created successfully in Firestore');
      } catch (firestoreError) {
        print('Google Sign-Up: Firestore profile creation failed: $firestoreError');
        // Sign out the user if profile creation fails
        await _auth.signOut();
        throw Exception('Failed to create user profile: $firestoreError');
      }
      
      // Sign out the user after creating profile so they can sign in manually
      print('Google Sign-Up: Signing out user to allow manual sign-in');
      await _auth.signOut();
      
      print('Google Sign-Up: New user profile created successfully');
    } catch (e) {
      print('Google Sign-Up error: $e');
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password, String fullName) async {
    try {
      // Bypass reCAPTCHA by using a different approach
      // Create user with Firebase without reCAPTCHA
      UserCredential userCredential;
      
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (recaptchaError) {
        // If reCAPTCHA still fails, throw specific error
        print('reCAPTCHA error: $recaptchaError');
        throw Exception('RECAPTCHA_DISABLED_ERROR: Please disable reCAPTCHA in Firebase Console');
      }

      // Create user profile in Firestore (non-blocking)
      _createUserProfile(userCredential.user!.uid, fullName, email);

      // Update display name (non-blocking)
      _updateDisplayName(userCredential.user!, fullName);

      return userCredential;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Helper method to create user profile (non-blocking)
  Future<void> _createUserProfile(String uid, String fullName, String email) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'fullName': fullName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'photoURL': null,
      });
    } catch (e) {
      print('Firestore profile creation failed: $e');
      // Don't throw error, just log it
    }
  }

  // Helper method to update display name (non-blocking)
  Future<void> _updateDisplayName(User user, String fullName) async {
    try {
      await user.updateDisplayName(fullName);
    } catch (e) {
      print('Display name update failed: $e');
      // Don't throw error, just log it
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      await _auth.currentUser!.updateDisplayName(displayName);
      if (photoURL != null) {
        await _auth.currentUser!.updatePhotoURL(photoURL);
      }
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Failed to get user data: $e');
      return null;
    }
  }

  // Check if Firebase is properly configured and working
  Future<bool> isFirebaseAvailable() async {
    try {
      // Try to access Firestore to verify connection
      await _firestore.collection('users').limit(1).get();
      return true;
    } catch (e) {
      print('Firebase availability check failed: $e');
      return false;
    }
  }

  // Get current authentication state info
  Map<String, dynamic> getAuthStateInfo() {
    final user = _auth.currentUser;
    return {
      'isAuthenticated': user != null,
      'uid': user?.uid,
      'email': user?.email,
      'displayName': user?.displayName,
      'providerId': user?.providerData.firstOrNull?.providerId,
    };
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(dynamic e) {
    // Handle custom exceptions first (don't add prefix)
    if (e.toString().contains('Account not found. Please sign up first')) {
      return 'Account not found. Please sign up first using email/password or Google sign-up.';
    }
    
    if (e.toString().contains('An account with this email already exists')) {
      return 'An account with this email already exists. Please sign in instead.';
    }
    
    if (e.toString().contains('Google sign in was cancelled')) {
      return 'Google sign in was cancelled.';
    }
    
    if (e.toString().contains('Google sign up was cancelled')) {
      return 'Google sign up was cancelled.';
    }
    
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'invalid-email':
          return 'The email address is invalid.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'too-many-requests':
          return 'Too many requests. Try again later.';
        case 'operation-not-allowed':
          return 'Email/password accounts are not enabled.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection and try again.';
        case 'recaptcha-check-failed':
        case 'configuration-not-found':
          return 'RECAPTCHA_DISABLED_ERROR: Please disable reCAPTCHA in Firebase Console';
        default:
          return 'Authentication failed: ${e.message}';
      }
    }
    
    // Handle custom reCAPTCHA error
    if (e.toString().contains('RECAPTCHA_DISABLED_ERROR')) {
      return 'RECAPTCHA_DISABLED_ERROR: Please disable reCAPTCHA in Firebase Console';
    }
    
    // For any other unexpected errors, add the prefix
    return 'An unexpected error occurred: $e';
  }
}
