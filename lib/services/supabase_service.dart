import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

/// Service for initializing and accessing Supabase client
class SupabaseService {
  static bool _initialized = false;
  
  /// Initialize Supabase - call this in main() before runApp()
  static Future<void> initialize() async {
    if (_initialized) return;
    
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
    
    _initialized = true;
  }
  
  /// Get the Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;
  
  /// Get the current authenticated user
  static User? get currentUser => client.auth.currentUser;
  
  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;
  
  /// Get auth state changes stream
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}
