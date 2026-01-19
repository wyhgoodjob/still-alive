import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/emergency_contact.dart';
import '../services/supabase_service.dart';
import '../core/constants.dart';

/// Repository for emergency contacts operations
class ContactRepository {
  final SupabaseClient _client = SupabaseService.client;
  
  /// Get all contacts for current user
  Future<List<EmergencyContact>> getContacts() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];
    
    final response = await _client
        .from('emergency_contacts')
        .select()
        .eq('user_id', userId)
        .order('priority', ascending: true);
    
    return (response as List)
        .map((json) => EmergencyContact.fromJson(json))
        .toList();
  }
  
  /// Get contact by ID
  Future<EmergencyContact?> getContact(String id) async {
    final response = await _client
        .from('emergency_contacts')
        .select()
        .eq('id', id)
        .maybeSingle();
    
    if (response == null) return null;
    return EmergencyContact.fromJson(response);
  }
  
  /// Add a new contact
  Future<EmergencyContact?> addContact(EmergencyContact contact) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;
    
    // Check max contacts limit
    final existing = await getContacts();
    if (existing.length >= AppConstants.maxEmergencyContacts) {
      throw Exception('Maximum of ${AppConstants.maxEmergencyContacts} contacts allowed');
    }
    
    // Set priority based on existing contacts
    final newContact = contact.copyWith(
      userId: userId,
      priority: existing.length + 1,
    );
    
    final response = await _client
        .from('emergency_contacts')
        .insert(newContact.toInsertJson())
        .select()
        .single();
    
    return EmergencyContact.fromJson(response);
  }
  
  /// Update a contact
  Future<EmergencyContact?> updateContact(EmergencyContact contact) async {
    if (contact.id == null) return null;
    
    final response = await _client
        .from('emergency_contacts')
        .update({
          'name': contact.name,
          'phone_number': contact.phoneNumber,
          'relationship': contact.relationship,
          'priority': contact.priority,
        })
        .eq('id', contact.id!)
        .select()
        .single();
    
    return EmergencyContact.fromJson(response);
  }
  
  /// Delete a contact
  Future<void> deleteContact(String id) async {
    await _client
        .from('emergency_contacts')
        .delete()
        .eq('id', id);
    
    // Re-order remaining contacts
    await _reorderContacts();
  }
  
  /// Re-order contacts after deletion
  Future<void> _reorderContacts() async {
    final contacts = await getContacts();
    for (var i = 0; i < contacts.length; i++) {
      if (contacts[i].priority != i + 1) {
        await _client
            .from('emergency_contacts')
            .update({'priority': i + 1})
            .eq('id', contacts[i].id!);
      }
    }
  }
  
  /// Check if user has any contacts
  Future<bool> hasContacts() async {
    final contacts = await getContacts();
    return contacts.isNotEmpty;
  }
}
