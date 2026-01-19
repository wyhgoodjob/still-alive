import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/emergency_contact.dart';
import '../../models/user_settings.dart';
import '../../repositories/contact_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';

/// Settings screen for managing contacts, interval, message, and sign out
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _settingsRepo = SettingsRepository();
  final ContactRepository _contactRepo = ContactRepository();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  UserSettings? _settings;
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsRepo.getSettings();
      final contacts = await _contactRepo.getContacts();
      setState(() {
        _settings = settings;
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Emergency Contacts Section
                  _buildSectionHeader('Emergency Contacts', Icons.contacts),
                  const SizedBox(height: 8),
                  _buildContactsList(),
                  const SizedBox(height: 24),

                  // Check-in Interval Section
                  _buildSectionHeader('Check-in Interval', Icons.timer),
                  const SizedBox(height: 8),
                  _buildIntervalSelector(),
                  const SizedBox(height: 24),

                  // Alert Message Section
                  _buildSectionHeader('Alert Message', Icons.message),
                  const SizedBox(height: 8),
                  _buildAlertMessageCard(),
                  const SizedBox(height: 24),

                  // Notifications Section
                  _buildSectionHeader('Notifications', Icons.notifications),
                  const SizedBox(height: 8),
                  _buildNotificationsCard(),
                  const SizedBox(height: 32),

                  // Sign Out Button
                  _buildSignOutButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildContactsList() {
    return Card(
      child: Column(
        children: [
          ..._contacts.asMap().entries.map((entry) {
            final index = entry.key;
            final contact = entry.value;
            return Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Text(
                      contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ),
                  title: Text(contact.name),
                  subtitle: Text(contact.phoneNumber),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditContactDialog(contact),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _showDeleteContactDialog(contact),
                      ),
                    ],
                  ),
                ),
                if (index < _contacts.length - 1) const Divider(height: 1),
              ],
            );
          }),
          if (_contacts.length < AppConstants.maxEmergencyContacts)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade200,
                child: const Icon(Icons.add, color: Colors.grey),
              ),
              title: const Text('Add Contact'),
              subtitle: Text('${_contacts.length}/${AppConstants.maxEmergencyContacts} contacts'),
              onTap: _showAddContactDialog,
            ),
          if (_contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No emergency contacts yet.\nAdd at least one contact to receive alerts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntervalSelector() {
    final currentHours = _settings?.checkInIntervalHours ?? AppConstants.defaultCheckInIntervalHours;
    final days = currentHours / 24;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Check-in every:'),
                Text(
                  '${days.toStringAsFixed(days.truncateToDouble() == days ? 0 : 1)} day${days != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Slider(
              value: currentHours.toDouble(),
              min: AppConstants.minCheckInIntervalHours.toDouble(),
              max: AppConstants.maxCheckInIntervalHours.toDouble(),
              divisions: (AppConstants.maxCheckInIntervalHours - AppConstants.minCheckInIntervalHours) ~/ 24,
              label: '${days.toStringAsFixed(days.truncateToDouble() == days ? 0 : 1)} days',
              onChanged: (value) {
                setState(() {
                  _settings = _settings?.copyWith(checkInIntervalHours: value.round());
                });
              },
              onChangeEnd: (value) => _updateInterval(value.round()),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1 day', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text('7 days', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'If you don\'t check in within this time, your emergency contacts will be notified.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertMessageCard() {
    return Card(
      child: ListTile(
        title: const Text('Custom Alert Message'),
        subtitle: Text(
          _settings?.alertMessage ?? AppConstants.defaultAlertMessage,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _showEditMessageDialog,
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Test Notification'),
            subtitle: const Text('Send a test notification to verify setup'),
            trailing: const Icon(Icons.send),
            onTap: () async {
              await _notificationService.showTestNotification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test notification sent!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _updateInterval(int hours) async {
    try {
      final updated = await _settingsRepo.updateSettings(checkInIntervalHours: hours);
      if (updated != null) {
        setState(() => _settings = updated);
        
        // Reschedule notifications with new interval
        if (_settings?.nextCheckInDeadline != null) {
          await _notificationService.scheduleCheckInReminders(
            deadline: _settings!.nextCheckInDeadline!,
            intervalHours: hours,
          );
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Interval updated')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'John Doe',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '+1 234 567 8900',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(
                  labelText: 'Relationship (optional)',
                  hintText: 'Family, Friend, etc.',
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and phone are required')),
                );
                return;
              }
              Navigator.pop(context);
              await _addContact(
                nameController.text,
                phoneController.text,
                relationshipController.text.isEmpty ? null : relationshipController.text,
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addContact(String name, String phone, String? relationship) async {
    try {
      final contact = EmergencyContact(
        userId: _authService.currentUser!.id,
        name: name,
        phoneNumber: phone,
        relationship: relationship,
      );
      await _contactRepo.addContact(contact);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showEditContactDialog(EmergencyContact contact) {
    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phoneNumber);
    final relationshipController = TextEditingController(text: contact.relationship ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number *'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(labelText: 'Relationship (optional)'),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and phone are required')),
                );
                return;
              }
              Navigator.pop(context);
              await _updateContact(
                contact.copyWith(
                  name: nameController.text,
                  phoneNumber: phoneController.text,
                  relationship: relationshipController.text.isEmpty ? null : relationshipController.text,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateContact(EmergencyContact contact) async {
    try {
      await _contactRepo.updateContact(contact);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showDeleteContactDialog(EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to remove ${contact.name} from your emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteContact(contact);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    try {
      if (contact.id != null) {
        await _contactRepo.deleteContact(contact.id!);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact deleted')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showEditMessageDialog() {
    final messageController = TextEditingController(
      text: _settings?.alertMessage ?? AppConstants.defaultAlertMessage,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Alert Message'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Text(
                'Available variables:\n• {user_name} - Your name\n• {interval} - Check-in interval in hours',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              messageController.text = AppConstants.defaultAlertMessage;
            },
            child: const Text('Reset to Default'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateMessage(messageController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMessage(String message) async {
    try {
      final updated = await _settingsRepo.updateSettings(alertMessage: message);
      if (updated != null) {
        setState(() => _settings = updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message updated')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _notificationService.cancelAll();
        await _authService.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppConstants.routeLogin,
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      }
    }
  }
}
