// lib/main.dart
import 'package:ezeewash_admin/features/home/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/color/app_colors.dart';
import 'features/auth/admin_login_screen.dart';

// GLOBAL THEME NOTIFIER
final ValueNotifier<bool> darkModeNotifier = ValueNotifier(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  runApp(const AdminApp());
}

final supabase = Supabase.instance.client;

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'EzzeWash Admin',
          theme: ThemeData(
            // Use seed for better automatic dark mode transitions
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
            scaffoldBackgroundColor: AppColors.background,
            textTheme: GoogleFonts.alexandriaTextTheme(),
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}