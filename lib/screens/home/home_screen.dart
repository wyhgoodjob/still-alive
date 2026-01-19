import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/user_settings.dart';
import '../../repositories/settings_repository.dart';
import '../../services/notification_service.dart';

/// Main home screen with check-in button and countdown timer
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SettingsRepository _settingsRepo = SettingsRepository();
  final NotificationService _notificationService = NotificationService();
  
  UserSettings? _settings;
  bool _isLoading = true;
  bool _isCheckingIn = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsRepo.getSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
      _startCountdownTimer();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _performCheckIn() async {
    setState(() => _isCheckingIn = true);
    try {
      final updatedSettings = await _settingsRepo.checkIn();
      if (updatedSettings != null) {
        setState(() => _settings = updatedSettings);
        
        // Reschedule notifications
        if (_settings?.nextCheckInDeadline != null) {
          await _notificationService.scheduleCheckInReminders(
            deadline: _settings!.nextCheckInDeadline!,
            intervalHours: _settings!.checkInIntervalHours,
          );
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check-in successful! Stay safe.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isCheckingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Still Alive'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, AppConstants.routeHistory),
            tooltip: 'History',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.pushNamed(context, AppConstants.routeSettings);
              // Reload settings when returning from settings
              _loadSettings();
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 
                          AppBar().preferredSize.height - 
                          MediaQuery.of(context).padding.top,
                  child: _buildContent(),
                ),
              ),
            ),
    );
  }

  Widget _buildContent() {
    final timeRemaining = _settings?.timeRemaining;
    final isOverdue = _settings?.isOverdue ?? false;
    final hasCheckedInBefore = _settings?.lastCheckIn != null;

    return Column(
      children: [
        const Spacer(flex: 1),
        // Status indicator
        _buildStatusIndicator(timeRemaining, isOverdue, hasCheckedInBefore),
        const SizedBox(height: 32),
        // Countdown timer
        _buildCountdownDisplay(timeRemaining, isOverdue, hasCheckedInBefore),
        const SizedBox(height: 48),
        // Big check-in button
        _buildCheckInButton(),
        const Spacer(flex: 2),
        // Last check-in info
        if (hasCheckedInBefore) _buildLastCheckInInfo(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatusIndicator(Duration? timeRemaining, bool isOverdue, bool hasCheckedInBefore) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!hasCheckedInBefore) {
      statusColor = Colors.blue;
      statusText = 'Welcome! Tap to check in for the first time';
      statusIcon = Icons.waving_hand;
    } else if (isOverdue) {
      statusColor = Colors.red;
      statusText = 'OVERDUE - Check in now!';
      statusIcon = Icons.warning_rounded;
    } else if (timeRemaining != null) {
      final totalHours = _settings!.checkInIntervalHours;
      final remainingHours = timeRemaining.inHours;
      final percentRemaining = remainingHours / totalHours;

      if (percentRemaining > 0.5) {
        statusColor = Colors.green;
        statusText = 'All good!';
        statusIcon = Icons.check_circle;
      } else if (percentRemaining > 0.25) {
        statusColor = Colors.orange;
        statusText = 'Time to check in soon';
        statusIcon = Icons.schedule;
      } else {
        statusColor = Colors.deepOrange;
        statusText = 'Urgent: Check in!';
        statusIcon = Icons.timer;
      }
    } else {
      statusColor = Colors.grey;
      statusText = 'Loading...';
      statusIcon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownDisplay(Duration? timeRemaining, bool isOverdue, bool hasCheckedInBefore) {
    if (!hasCheckedInBefore) {
      return Column(
        children: [
          Text(
            '--:--:--',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No check-in yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      );
    }

    if (isOverdue) {
      return Column(
        children: [
          const Text(
            '00:00:00',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your contacts may be notified!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.red.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final hours = timeRemaining!.inHours;
    final minutes = timeRemaining.inMinutes % 60;
    final seconds = timeRemaining.inSeconds % 60;

    final totalHours = _settings!.checkInIntervalHours;
    final percentRemaining = hours / totalHours;
    Color timerColor;
    if (percentRemaining > 0.5) {
      timerColor = Colors.green;
    } else if (percentRemaining > 0.25) {
      timerColor = Colors.orange;
    } else {
      timerColor = Colors.deepOrange;
    }

    return Column(
      children: [
        Text(
          '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: timerColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'until your contacts are notified',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInButton() {
    final isOverdue = _settings?.isOverdue ?? false;

    return GestureDetector(
      onTap: _isCheckingIn ? null : _performCheckIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isCheckingIn
                ? [Colors.grey.shade400, Colors.grey.shade600]
                : isOverdue
                    ? [Colors.red.shade400, Colors.red.shade700]
                    : [Colors.green.shade400, Colors.green.shade700],
          ),
          boxShadow: [
            BoxShadow(
              color: (_isCheckingIn
                      ? Colors.grey
                      : isOverdue
                          ? Colors.red
                          : Colors.green)
                  .withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: _isCheckingIn
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "I'M ALIVE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLastCheckInInfo() {
    final lastCheckIn = _settings?.lastCheckIn;
    if (lastCheckIn == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final difference = now.difference(lastCheckIn);
    
    String timeAgo;
    if (difference.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (difference.inHours < 1) {
      timeAgo = '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      timeAgo = '${difference.inHours} hours ago';
    } else {
      final days = difference.inDays;
      timeAgo = '$days day${days > 1 ? 's' : ''} ago';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Text(
            'Last check-in: $timeAgo',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
