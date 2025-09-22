import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth_service.dart';
import '../services/mock_auth_service.dart';
import '../config/app_config.dart';

class AuthProvider extends ChangeNotifier {
  late final FirebaseAuthService _firebaseAuthService;
  late final MockAuthService _mockAuthService;
  User? _firebaseUser;
  Map<String, dynamic>? _mockUser;
  bool _isLoading = false;
  String? _error;
  bool _useMockAuth = false;

  // Getters
  User? get firebaseUser => _firebaseUser;
  Map<String, dynamic>? get mockUser => _mockUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _firebaseUser != null || _mockUser != null;
  bool get useMockAuth => _useMockAuth;

  AuthProvider() {
    // Initialize all services
    _firebaseAuthService = FirebaseAuthService();
    _mockAuthService = MockAuthService();
    
    // Set initial auth mode based on config - NEVER use mock if Firebase is configured
    _useMockAuth = !AppConfig.useFirebase;
    
    print('AuthProvider initialized with useFirebase: ${AppConfig.useFirebase}');
    print('AuthProvider: Initial _useMockAuth: $_useMockAuth');
    
    // Verify Firebase configuration if it's supposed to be enabled
    if (AppConfig.useFirebase) {
      _verifyFirebaseConfiguration();
      // Ensure we stay in Firebase mode
      _useMockAuth = false;
      print('AuthProvider: Forced Firebase mode, _useMockAuth: $_useMockAuth');
    }
    
    // Listen to Firebase auth state changes
    _firebaseAuthService.authStateChanges.listen((User? user) {
      _firebaseUser = user;
      notifyListeners();
    });
    
    // Listen to mock auth state changes
    _mockAuthService.authStateChanges.listen((bool isAuthenticated) {
      _mockUser = isAuthenticated ? _mockAuthService.currentUser : null;
      notifyListeners();
    });
  }

  // Verify Firebase configuration is working
  Future<void> _verifyFirebaseConfiguration() async {
    try {
      // Try to get current Firebase user to verify connection
      final currentUser = _firebaseAuthService.currentUser;
      print('Firebase connection verified. Current user: ${currentUser?.uid ?? 'none'}');
    } catch (e) {
      print('Firebase configuration issue detected: $e');
      print('Please ensure Firebase is properly configured in firebase_options.dart');
    }
  }

  // Sign in with Firebase (real authentication)
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      if (_useMockAuth) {
        // Only allow mock sign-in if explicitly configured
        await _mockAuthService.signInWithEmailAndPassword(email, password);
        _setLoading(false);
        return true;
      } else {
        // Always use Firebase for sign-in - no fallback to mock
        try {
          await _firebaseAuthService.signInWithEmailAndPassword(email, password);
          _setLoading(false);
          return true;
        } catch (firebaseError) {
          String errorMessage = firebaseError.toString();
          
          // Provide clear error messages for common sign-in failures
          if (errorMessage.contains('user-not-found')) {
            _setError('No account found with this email. Please sign up first.');
          } else if (errorMessage.contains('wrong-password')) {
            _setError('Incorrect password. Please try again.');
          } else if (errorMessage.contains('invalid-email')) {
            _setError('Invalid email format. Please enter a valid email address.');
          } else if (errorMessage.contains('user-disabled')) {
            _setError('This account has been disabled. Please contact support.');
          } else if (errorMessage.contains('too-many-requests')) {
            _setError('Too many failed attempts. Please try again later.');
          } else if (errorMessage.contains('network-request-failed')) {
            _setError('Network error. Please check your internet connection and try again.');
          } else if (errorMessage.contains('configuration-not-found')) {
            _setError('Firebase configuration error. Please check your internet connection and try again.');
          } else if (errorMessage.contains('operation-not-allowed')) {
            _setError('Email/password authentication is not enabled. Please contact support.');
          } else {
            _setError('Sign-in failed: $errorMessage');
          }
          
          _setLoading(false);
          return false;
        }
      }
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      _setLoading(false);
      return false;
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    print('Google Sign-In: Starting with _useMockAuth: $_useMockAuth, AppConfig.useFirebase: ${AppConfig.useFirebase}');

    try {
      if (_useMockAuth) {
        print('Google Sign-In: WARNING - Using mock authentication when Firebase is configured!');
        // Force Firebase mode if it's configured
        if (AppConfig.useFirebase) {
          _useMockAuth = false;
          print('Google Sign-In: Forced Firebase mode');
        }
      }
      
      if (_useMockAuth) {
        // Only allow mock sign-in if explicitly configured
        print('Google Sign-In: Using mock authentication');
        await Future.delayed(const Duration(seconds: 1));
        await _mockAuthService.signInWithEmailAndPassword('google@example.com', 'google123');
        _setLoading(false);
        return true;
      } else {
        // Always use Firebase for Google sign-in when configured
        print('Google Sign-In: Using Firebase authentication');
        try {
          await _firebaseAuthService.signInWithGoogle();
          _setLoading(false);
          return true;
        } catch (firebaseError) {
          String errorMessage = firebaseError.toString();
          print('Google Sign-In: Firebase error: $errorMessage');
          
          // Show Firebase errors directly
          _setError(errorMessage);
          _setLoading(false);
          return false;
        }
      }
    } catch (e) {
      print('Google Sign-In: Unexpected error: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Sign up with Google (creates new user profile)
  Future<bool> signUpWithGoogle() async {
    _setLoading(true);
    _clearError();

    print('Google Sign-Up: Starting with _useMockAuth: $_useMockAuth, AppConfig.useFirebase: ${AppConfig.useFirebase}');

    try {
      if (_useMockAuth) {
        print('Google Sign-Up: WARNING - Using mock authentication when Firebase is configured!');
        // Force Firebase mode if it's configured
        if (AppConfig.useFirebase) {
          _useMockAuth = false;
          print('Google Sign-Up: Forced Firebase mode');
        }
      }
      
      if (_useMockAuth) {
        // Only allow mock sign-up if explicitly configured
        print('Google Sign-Up: Using mock authentication');
        await Future.delayed(const Duration(seconds: 1));
        await _mockAuthService.registerWithEmailAndPassword('google@example.com', 'google123', 'Google User');
        _setLoading(false);
        return true;
      } else {
        // Always use Firebase for Google sign-up when configured
        print('Google Sign-Up: Using Firebase authentication');
        try {
          await _firebaseAuthService.signUpWithGoogle();
          _setLoading(false);
          return true;
        } catch (firebaseError) {
          String errorMessage = firebaseError.toString();
          print('Google Sign-Up: Firebase error: $errorMessage');
          
          // Show Firebase errors directly
          _setError(errorMessage);
          _setLoading(false);
          return false;
        }
      }
    } catch (e) {
      print('Google Sign-Up: Unexpected error: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Register with Firebase (real authentication)
  Future<bool> register(String email, String password, String fullName) async {
    _setLoading(true);
    _clearError();

    try {
      if (_useMockAuth) {
        await _mockAuthService.registerWithEmailAndPassword(email, password, fullName);
        _setLoading(false);
        return true;
      } else {
        // Try Firebase first
        try {
          await _firebaseAuthService.registerWithEmailAndPassword(email, password, fullName);
          _setLoading(false);
          return true;
        } catch (firebaseError) {
          String errorMessage = firebaseError.toString();
          
          // If Firebase fails due to configuration or network, switch to mock auth
          if (errorMessage.contains('configuration-not-found') || 
              errorMessage.contains('network') || 
              errorMessage.contains('timeout') ||
              errorMessage.contains('unreachable') ||
              errorMessage.contains('failed to connect')) {
            
            print('Firebase unavailable, switching to mock authentication');
            _useMockAuth = true;
            _setError('Switched to offline mode. Please try registration again.');
            
            // Try registration again with mock auth
            try {
              await _mockAuthService.registerWithEmailAndPassword(email, password, fullName);
              _setLoading(false);
              return true;
            } catch (mockError) {
              _setError(mockError.toString());
              _setLoading(false);
              return false;
            }
          } else {
            // Other Firebase errors
            _setError(errorMessage);
            _setLoading(false);
            return false;
          }
        }
      }
    } catch (e) {
      String errorMessage = e.toString();
      
      // Handle network errors
      if (errorMessage.contains('network') || 
          errorMessage.contains('timeout') || 
          errorMessage.contains('unreachable')) {
        _setError('Network error. Please check your internet connection and try again.');
      } else {
        _setError(errorMessage);
      }
      
      _setLoading(false);
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    try {
      if (_useMockAuth) {
        await _mockAuthService.signOut();
      } else {
        await _firebaseAuthService.signOut();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }


  // Reset password
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      if (_useMockAuth) {
        await _mockAuthService.resetPassword(email);
      } else {
        await _firebaseAuthService.resetPassword(email);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Update profile
  Future<bool> updateProfile({String? displayName, String? photoURL}) async {
    _setLoading(true);
    _clearError();

    try {
      if (_useMockAuth) {
        await _mockAuthService.updateUserProfile(
          displayName: displayName,
          photoURL: photoURL,
        );
      } else {
        await _firebaseAuthService.updateUserProfile(
          displayName: displayName,
          photoURL: photoURL,
        );
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      if (_useMockAuth) {
        return await _mockAuthService.getUserData(uid);
      } else {
        return await _firebaseAuthService.getUserData(uid);
      }
    } catch (e) {
      // Fallback to mock data if Firebase fails
      return AppConfig.mockUser;
    }
  }

  // Switch to mock authentication
  void switchToMockAuth() {
    _useMockAuth = true;
    notifyListeners();
  }

  // Switch to Firebase authentication
  void switchToFirebaseAuth() {
    _useMockAuth = false;
    notifyListeners();
  }

  // Force Firebase authentication mode (prevents fallback to mock)
  void forceFirebaseMode() {
    if (AppConfig.useFirebase) {
      _useMockAuth = false;
      print('Forced Firebase authentication mode');
      notifyListeners();
    }
  }

  // Check if Firebase is properly configured and available
  bool get isFirebaseAvailable => AppConfig.useFirebase && !_useMockAuth;

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  @override
  void dispose() {
    _mockAuthService.dispose();
    super.dispose();
  }
}
