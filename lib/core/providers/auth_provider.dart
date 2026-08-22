import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

/// Auth state provider
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    // Mock user login state (set to true to auto-login, or false to require login click)
    _user = null;
    notifyListeners();
  }

  /// Sign up with email
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String preferredLanguage = 'en',
    List<String> interests = const [],
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1)); // Mock network delay
    _user = UserModel(
      uid: 'mock_uid_123',
      name: name,
      email: email,
      preferredLanguage: preferredLanguage,
      interests: interests,
    );
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Sign in with email
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1)); // Mock network delay
    _user = UserModel(
      uid: 'mock_uid_123',
      name: 'Mock User',
      email: email,
      preferredLanguage: 'en',
      interests: ['Food', 'Culture'],
    );
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1)); // Mock network delay
    _user = UserModel(
      uid: 'mock_uid_123',
      name: 'Google User',
      email: 'google@example.com',
      preferredLanguage: 'en',
      interests: [],
    );
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Update user profile
  Future<void> updateProfile(UserModel updatedUser) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _user = updatedUser;
    notifyListeners();
  }

  /// Sign out
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _user = null;
    notifyListeners();
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
