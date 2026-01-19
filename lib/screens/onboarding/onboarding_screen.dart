import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/emergency_contact.dart';
import '../../repositories/contact_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';

/// Onboarding screen with multi-step wizard
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _contactRepository = ContactRepository();
  final _settingsRepository = SettingsRepository();
  final _notificationService = NotificationService();
  
  int _currentPage = 0;
  bool _isLoading = false;
  
  // Contact form
  final _contactFormKey = GlobalKey<FormState>();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactRelationshipController = TextEditingController();
  
  // Settings
  int _checkInIntervalHours = AppConstants.defaultCheckInIntervalHours;
  final _alertMessageController = TextEditingController(
    text: AppConstants.defaultAlertMessage,
  );

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactRelationshipController.dispose();
    _alertMessageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveContactAndContinue() async {
    if (!_contactFormKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');
      
      final contact = EmergencyContact(
        userId: userId,
        name: _contactNameController.text.trim(),
        phoneNumber: _contactPhoneController.text.trim(),
        relationship: _contactRelationshipController.text.trim().isEmpty
            ? null
            : _contactRelationshipController.text.trim(),
        priority: 1,
      );
      
      await _contactRepository.addContact(contact);
      _nextPage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);
    
    try {
      // Update settings
      await _settingsRepository.updateSettings(
        checkInIntervalHours: _checkInIntervalHours,
        alertMessage: _alertMessageController.text.trim(),
      );
      
      // Perform initial check-in
      final settings = await _settingsRepository.checkIn();
      
      // Request notification permissions and schedule reminders
      await _notificationService.requestPermissions();
      if (settings != null && settings.nextCheckInDeadline != null) {
        await _notificationService.scheduleCheckInReminders(
          deadline: settings.nextCheckInDeadline!,
          intervalHours: settings.checkInIntervalHours,
        );
      }
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildWelcomePage(),
                  _buildContactPage(),
                  _buildSettingsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          const Text(
            'Welcome to Still Alive',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'This app helps you stay connected with your loved ones. '
            'Simply check in regularly, and if you don\'t, we\'ll notify your emergency contacts.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: _nextPage,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            ),
            child: const Text('Get Started', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add Emergency Contact',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This person will be notified if you don\'t check in on time.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          
          Form(
            key: _contactFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _contactNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Contact Name *',
                    prefixIcon: Icon(Icons.person_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                    hintText: '+1 234 567 8900',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactRelationshipController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Relationship (optional)',
                    prefixIcon: Icon(Icons.people_outlined),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Spouse, Parent, Friend',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          Row(
            children: [
              TextButton(
                onPressed: _previousPage,
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _isLoading ? null : _saveContactAndContinue,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Configure Check-in',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set how often you need to check in.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          
          // Interval selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Check-in Interval',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _formatInterval(_checkInIntervalHours),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Slider(
                    value: _checkInIntervalHours.toDouble(),
                    min: AppConstants.minCheckInIntervalHours.toDouble(),
                    max: AppConstants.maxCheckInIntervalHours.toDouble(),
                    divisions: 6,
                    label: _formatInterval(_checkInIntervalHours),
                    onChanged: (value) {
                      setState(() => _checkInIntervalHours = value.round());
                    },
                  ),
                  Text(
                    'Your contacts will be alerted if you don\'t check in within this time.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Alert message
          const Text(
            'Alert Message',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _alertMessageController,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Message sent to your emergency contacts',
              helperText: 'Use {user_name} and {interval} as placeholders',
            ),
          ),
          const SizedBox(height: 32),
          
          Row(
            children: [
              TextButton(
                onPressed: _previousPage,
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _isLoading ? null : _completeOnboarding,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Complete Setup'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatInterval(int hours) {
    if (hours < 24) {
      return '$hours hours';
    } else if (hours == 24) {
      return '1 day';
    } else {
      final days = hours ~/ 24;
      return '$days days';
    }
  }
}
