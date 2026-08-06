import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'package:attendance_system/services/notification_service.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    // Run initialization in the background
    try {
      await MongoDBService.init();
      await NotificationService().init();
    } catch (e) {
      debugPrint("Initialization error: $e");
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Center logo
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/app_icon.jpg',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
                    color: Colors.red[100],
                    child: const Icon(Icons.school, size: 60, color: Color(0xFFB71C1C)),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            // Progress Bar Matching Theme
            SizedBox(
              width: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: Color(0xFFFFCDD2), // Light red background
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB71C1C)), // Dark red matching theme
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
