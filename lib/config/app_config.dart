class AppConfig {
  // Set this to false to use mock authentication (for development without Firebase)
  // Set to true for real Firebase authentication
  static const bool useFirebase = true; // Use real Firebase authentication
  
  // Set this to false since reCAPTCHA will be disabled in Firebase
  static const bool bypassRecaptcha = false;
  
  // Mock user data for development (fallback)
  static const Map<String, dynamic> mockUser = {
    'uid': 'mock-user-id',
    'email': 'test@example.com',
    'displayName': 'Test User',
  };
}
