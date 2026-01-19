import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import 'supabase_service.dart';

/// Service for handling authentication
class AuthService {
  final SupabaseClient _client = SupabaseService.client;
  
  /// Get current user
  User? get currentUser => _client.auth.currentUser;
  
  /// Check if user is signed in
  bool get isSignedIn => currentUser != null;
  
  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
      emailRedirectTo: kIsWeb ? null : AppConstants.authCallbackUrl,
    );
    return response;
  }
  
  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }
  
  /// Sign in with Google
  Future<AuthResponse> signInWithGoogle() async {
    // Configure Google Sign In
    const webClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'; // TODO: Replace with actual
    
    final GoogleSignIn googleSignIn = GoogleSignIn(
      serverClientId: webClientId,
    );
    
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthException('Google sign in was cancelled');
    }
    
    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;
    
    if (accessToken == null) {
      throw AuthException('No access token found');
    }
    if (idToken == null) {
      throw AuthException('No ID token found');
    }
    
    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }
  
  /// Sign in with Apple
  Future<AuthResponse> signInWithApple() async {
    // Generate a random nonce
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    
    // Request credential from Apple
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw AuthException('No identity token found');
    }
    
    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }
  
  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
  
  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: AppConstants.authCallbackUrl,
    );
  }
  
  /// Generate a random nonce for Apple Sign In
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }
}
