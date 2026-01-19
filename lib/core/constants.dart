/// App-wide constants and configuration
class AppConstants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://nvjzyblxtusioknixlff.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52anp5Ymx4dHVzaW9rbml4bGZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg2MjkwNTksImV4cCI6MjA4NDIwNTA1OX0.40vcz45enlu4VFLVcGwwGb4bvdWcMrPwbuF0pGAZkus';
  
  // Deep link scheme for auth callback
  static const String authCallbackUrlScheme = 'io.supabase.stillalive';
  static const String authCallbackUrl = 'io.supabase.stillalive://login-callback';
  
  // Default Settings
  static const int defaultCheckInIntervalHours = 48; // 2 days
  static const int minCheckInIntervalHours = 24;     // 1 day
  static const int maxCheckInIntervalHours = 168;    // 7 days
  static const int maxEmergencyContacts = 3;
  
  // Default Alert Message
  static const String defaultAlertMessage = 
    '🚨 STILL ALIVE ALERT: {user_name} has not checked in for {interval} hours. '
    'This is an automated safety alert. Please try to contact them.';
  
  // Route Names
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeOnboarding = '/onboarding';
  static const String routeHome = '/home';
  static const String routeSettings = '/settings';
  static const String routeHistory = '/history';
  
  // History Settings
  static const int historyRetentionDays = 365; // 1 year
}
