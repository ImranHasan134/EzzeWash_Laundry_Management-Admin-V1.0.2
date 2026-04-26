// lib/features/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/admin_login_screen.dart';

enum GifSize { small, medium, large, custom }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isExiting = false;
  bool _showBranding = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showBranding = true);
    });

    _startExitTimer();
  }

  Future<void> _startExitTimer() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    setState(() {
      _isExiting = true;
      _showBranding = false;
    });

    await Future.delayed(const Duration(milliseconds: 800));
    _navigateToNext();
  }

  void _navigateToNext() {
    if (!mounted) return;

    // --- SECURE AUTHENTICATION ROUTING ---
    // Check if the admin is already logged in
    final session = Supabase.instance.client.auth.currentSession;

    // Route to Dashboard if logged in, otherwise route to Login Screen
    final Widget nextScreen = const AdminLoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1000),
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
      ),
    );
  }

  double _getGifSize(GifSize size) {
    final screenWidth = MediaQuery.of(context).size.width;
    switch (size) {
      case GifSize.small: return screenWidth * 0.4;
      case GifSize.large: return screenWidth * 0.8;
      case GifSize.medium: return screenWidth * 0.6;
      case GifSize.custom: default: return 350.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double currentSize = _getGifSize(GifSize.custom);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 750),
              opacity: _isExiting ? 0.0 : 1.0,
              child: Image.asset(
                'assets/icon/splash.gif',
                width: 5000,
                height: 5000,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 800),
                  opacity: _showBranding ? 1.0 : 0.0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    offset: _showBranding ? Offset.zero : const Offset(0, 0.5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('A', style: TextStyle(color: Colors.black, fontSize: 12, letterSpacing: 2)),
                        const SizedBox(height: 6),
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF05BCFF), Color(0xFF6366F1), Color(0xFF312E81)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text('Ezze Softwares', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        ),
                        const SizedBox(height: 6),
                        const Text('PRODUCT', style: TextStyle(color: Colors.black, fontSize: 10, letterSpacing: 5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}