import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/supabase_service.dart';
import '../repositories/settings_repository.dart';

/// Splash screen that checks auth state and routes accordingly
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndRoute();
  }
  
  Future<void> _checkAuthAndRoute() async {
    // Small delay for splash branding
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;
    
    // Check if user is authenticated
    if (!SupabaseService.isAuthenticated) {
      _navigateTo(AppConstants.routeLogin);
      return;
    }
    
    // Check if onboarding is complete (has at least one contact)
    final settingsRepo = SettingsRepository();
    final hasOnboarded = await settingsRepo.hasCompletedOnboarding();
    
    if (!mounted) return;
    
    if (hasOnboarded) {
      _navigateTo(AppConstants.routeHome);
    } else {
      _navigateTo(AppConstants.routeOnboarding);
    }
  }
  
  void _navigateTo(String route) {
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.favorite,
                size: 60,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            // App Name
            const Text(
              'Still Alive',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your safety check-in app',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 48),
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
