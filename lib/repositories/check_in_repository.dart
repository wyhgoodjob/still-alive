import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/check_in.dart';
import '../services/supabase_service.dart';

/// Repository for check-in history operations
class CheckInRepository {
  final SupabaseClient _client = SupabaseService.client;
  
  /// Get check-in history for current user
  Future<List<CheckIn>> getHistory({int limit = 50, int offset = 0}) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];
    
    final response = await _client
        .from('check_in_history')
        .select()
        .eq('user_id', userId)
        .order('check_in_time', ascending: false)
        .range(offset, offset + limit - 1);
    
    return (response as List)
        .map((json) => CheckIn.fromJson(json))
        .toList();
  }
  
  /// Get total check-in count
  Future<int> getCheckInCount() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return 0;
    
    final response = await _client
        .from('check_in_history')
        .select('id')
        .eq('user_id', userId)
        .count(CountOption.exact);
    
    return response.count ?? 0;
  }
  
  /// Get check-ins within a date range
  Future<List<CheckIn>> getHistoryInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];
    
    final response = await _client
        .from('check_in_history')
        .select()
        .eq('user_id', userId)
        .gte('check_in_time', startDate.toIso8601String())
        .lte('check_in_time', endDate.toIso8601String())
        .order('check_in_time', ascending: false);
    
    return (response as List)
        .map((json) => CheckIn.fromJson(json))
        .toList();
  }
  
  /// Get the most recent check-in
  Future<CheckIn?> getLastCheckIn() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;
    
    final response = await _client
        .from('check_in_history')
        .select()
        .eq('user_id', userId)
        .order('check_in_time', ascending: false)
        .limit(1)
        .maybeSingle();
    
    if (response == null) return null;
    return CheckIn.fromJson(response);
  }
}
