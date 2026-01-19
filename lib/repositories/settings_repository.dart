import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_settings.dart';
import '../services/supabase_service.dart';

/// Repository for user settings operations
class SettingsRepository {
  final SupabaseClient _client = SupabaseService.client;
  
  /// Get current user's settings
  Future<UserSettings?> getSettings() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;
    
    final response = await _client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    
    if (response == null) return null;
    return UserSettings.fromJson(response);
  }
  
  /// Update user settings
  Future<UserSettings?> updateSettings({
    int? checkInIntervalHours,
    String? alertMessage,
    String? timezone,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;
    
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (checkInIntervalHours != null) {
      updates['check_in_interval_hours'] = checkInIntervalHours;
    }
    if (alertMessage != null) {
      updates['alert_message'] = alertMessage;
    }
    if (timezone != null) {
      updates['timezone'] = timezone;
    }
    
    final response = await _client
        .from('user_settings')
        .update(updates)
        .eq('user_id', userId)
        .select()
        .single();
    
    return UserSettings.fromJson(response);
  }
  
  /// Perform a check-in (updates last_check_in timestamp)
  Future<UserSettings?> checkIn() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;
    
    final now = DateTime.now().toIso8601String();
    
    final response = await _client
        .from('user_settings')
        .update({
          'last_check_in': now,
          'alert_sent': false,
          'updated_at': now,
        })
        .eq('user_id', userId)
        .select()
        .single();
    
    return UserSettings.fromJson(response);
  }
  
  /// Check if user has completed onboarding (has at least one contact)
  Future<bool> hasCompletedOnboarding() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;
    
    final response = await _client
        .from('emergency_contacts')
        .select('id')
        .eq('user_id', userId)
        .limit(1);
    
    return (response as List).isNotEmpty;
  }
}
