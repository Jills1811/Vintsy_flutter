import 'dart:async';
import '../config/app_config.dart';

class MockAuthService {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();
  
  // Store registered users for mock authentication
  static final Map<String, Map<String, dynamic>> _registeredUsers = {
    'test@example.com': {
      'password': '123456',
      'displayName': 'Test User',
    },
    'google@example.com': {
      'password': 'google123',
      'displayName': 'Google User',
    },
  };

  // Get current user
  Map<String, dynamic>? get currentUser => _currentUser;

  // Auth state changes stream
  Stream<bool> get authStateChanges => _authStateController.stream;

  // Sign in with email and password
  Future<Map<String, dynamic>> signInWithEmailAndPassword(
      String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Check if user is registered
    if (_registeredUsers.containsKey(email)) {
      final userData = _registeredUsers[email]!;
      if (userData['password'] == password) {
        // Create user object
        _currentUser = {
          'uid': 'mock-user-${email.hashCode}',
          'email': email,
          'displayName': userData['displayName'],
          'photoURL': email == 'google@example.com' 
              ? 'https://lh3.googleusercontent.com/a/default-user'
              : null,
          'provider': email == 'google@example.com' ? 'google' : 'email',
        };
        
        _isAuthenticated = true;
        _authStateController.add(true);
        return _currentUser!;
      }
    }
    
    throw Exception('Invalid email or password');
  }

  // Register with email and password
  Future<Map<String, dynamic>> registerWithEmailAndPassword(
      String email, String password, String fullName) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Check if user already exists
    if (_registeredUsers.containsKey(email)) {
      throw Exception('An account already exists with this email');
    }
    
    // Add new user to registered users
    _registeredUsers[email] = {
      'password': password,
      'displayName': fullName,
    };
    
    // Mock registration
    _currentUser = {
      'uid': 'mock-user-${email.hashCode}',
      'email': email,
      'displayName': fullName,
      'provider': 'email',
    };
    _isAuthenticated = true;
    _authStateController.add(true);
    return _currentUser!;
  }

  // Sign out
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
    _isAuthenticated = false;
    _authStateController.add(false);
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await Future.delayed(const Duration(seconds: 1));
    // Mock password reset
    print('Password reset email sent to: $email');
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (displayName != null && _currentUser != null) {
      _currentUser!['displayName'] = displayName;
    }
    if (photoURL != null && _currentUser != null) {
      _currentUser!['photoURL'] = photoURL;
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _currentUser;
  }

  // Check if user is authenticated
  bool get isAuthenticated => _isAuthenticated;

  // Dispose
  void dispose() {
    _authStateController.close();
  }
}
