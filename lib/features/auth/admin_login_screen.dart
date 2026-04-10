// lib/features/auth/admin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../core/theme/color/app_colors.dart';
import '../../main.dart';
import '../home/dashboard_screen.dart';

// --- DYNAMIC THEME HELPERS ---
bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
Color _surfaceColor(BuildContext context) => _isDark(context) ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white.withOpacity(0.85);
Color _textColor(BuildContext context) => _isDark(context) ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
Color _subtextColor(BuildContext context) => _isDark(context) ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
Color _borderColor(BuildContext context) => _isDark(context) ? const Color(0xFF475569) : const Color(0xFFE2E8F0);
Color _inputFillColor(BuildContext context) => _isDark(context) ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC).withOpacity(0.8);

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> with TickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool _loading  = false;
  bool _obscure  = true;
  String? _error;

  // Animations
  late AnimationController _entranceCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  late AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();

    // Entrance Animation (Slide up & Fade in)
    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();

    // Subtle Logo Pulse Animation
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Floating Background Bubbles Animation
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final res = await supabase.auth.signInWithPassword(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      if (res.user == null) throw Exception('Login failed');

      final String userEmail = res.user!.email!;

      // Super Admin bypass or check whitelist
      if (userEmail != 'imranhasan13421@gmail.com') {
        final teamRes = await supabase.from('team_members')
            .select()
            .eq('email', userEmail)
            .maybeSingle();

        if (teamRes == null) {
          await supabase.auth.signOut();
          setState(() {
            _error   = 'Access denied. You are not on the Manager whitelist.';
            _loading = false;
          });
          return;
        }
      }

      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
    } on AuthApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  InputDecoration _deco(BuildContext context, String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(color: _subtextColor(context).withOpacity(0.6), fontSize: 14),
    prefixIcon: Icon(icon, color: _subtextColor(context), size: 20),
    filled: true,
    fillColor: _inputFillColor(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _borderColor(context))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _borderColor(context))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2.0)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.error.withOpacity(0.5), width: 1.5)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.error, width: 2.0)),
  );

  Widget _buildBubble(double size, Color color, double opacity) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(opacity)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark(context);
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Base Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFE0E7FF)],
              ),
            ),
          ),

          // 2. Animated Floating Bubbles
          AnimatedBuilder(
            animation: _floatCtrl,
            builder: (context, child) {
              final t = _floatCtrl.value * 2 * math.pi;
              final opacity = isDark ? 0.15 : 0.2;

              return Stack(
                children: [
                  // Top Left Large Bubble
                  Positioned(
                    top: -100 + 60 * math.sin(t),
                    left: -50 + 60 * math.cos(t),
                    child: _buildBubble(sw * 0.4, AppColors.primary, opacity),
                  ),
                  // Bottom Right Large Bubble
                  Positioned(
                    bottom: -150 + 80 * math.cos(t + math.pi / 4),
                    right: -100 + 80 * math.sin(t + math.pi / 4),
                    child: _buildBubble(sw * 0.5, const Color(0xFF8B5CF6), opacity),
                  ),
                  // Center Left Medium Bubble
                  Positioned(
                    top: sh * 0.4 + 50 * math.sin(t + math.pi),
                    left: sw * 0.1 + 50 * math.cos(t + math.pi),
                    child: _buildBubble(sw * 0.15, const Color(0xFF3B82F6), opacity),
                  ),
                  // Bottom Center Small Bubble
                  Positioned(
                    bottom: sh * 0.15 + 40 * math.cos(t + math.pi / 2),
                    left: sw * 0.3 + 40 * math.sin(t + math.pi / 2),
                    child: _buildBubble(sw * 0.08, AppColors.primary, opacity),
                  ),
                  // Top Right Medium Bubble
                  Positioned(
                    top: sh * 0.1 + 70 * math.sin(t + math.pi * 1.5),
                    right: sw * 0.15 + 70 * math.cos(t + math.pi * 1.5),
                    child: _buildBubble(sw * 0.2, const Color(0xFF6366F1), opacity),
                  ),
                ],
              );
            },
          ),

          // 3. Frosted Glass Blur overlay to make bubbles soft
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(color: Colors.transparent),
          ),

          // 4. Main Login Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0), // Glassmorphism on the card
                      child: Container(
                        width: 460,
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
                        decoration: BoxDecoration(
                          color: _surfaceColor(context),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white.withOpacity(isDark ? 0.05 : 0.5), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 20))
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Animated Logo
                                ScaleTransition(
                                  scale: _pulseAnim,
                                  child: Container(
                                    height: 80, width: 80,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.gradient,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 10))],
                                    ),
                                    child: const Icon(Icons.local_laundry_service, color: Colors.white, size: 40),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Text('EzeeWash Workspace', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: _textColor(context))),
                                const SizedBox(height: 8),
                                Text('Sign in to your administration dashboard', style: GoogleFonts.inter(fontSize: 15, color: _subtextColor(context))),
                                const SizedBox(height: 40),

                                // Animated Error Banner
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  child: _error != null
                                      ? Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 24),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.error.withOpacity(0.3))),
                                    child: Row(children: [
                                      const Icon(Icons.error_outline, color: AppColors.error, size: 22),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4))),
                                    ]),
                                  )
                                      : const SizedBox.shrink(),
                                ),

                                Align(alignment: Alignment.centerLeft, child: Text('Email Address', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _textColor(context)))),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  style: GoogleFonts.inter(fontSize: 15, color: _textColor(context), fontWeight: FontWeight.w500),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                                  decoration: _deco(context, 'example@ezeewash.com', Icons.email_outlined),
                                ),
                                const SizedBox(height: 24),

                                Align(alignment: Alignment.centerLeft, child: Text('Password', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _textColor(context)))),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscure,
                                  style: GoogleFonts.inter(fontSize: 15, color: _textColor(context), fontWeight: FontWeight.w500),
                                  onFieldSubmitted: (_) => _handleLogin(),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Password is required' : null,
                                  decoration: _deco(context, 'Enter your password', Icons.lock_outline).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _subtextColor(context), size: 20),
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                      splashRadius: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),

                                // Login Button
                                SizedBox(
                                  width: double.infinity, height: 56,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    decoration: BoxDecoration(
                                      gradient: _loading ? null : AppColors.gradient,
                                      color: _loading ? _borderColor(context) : null,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: _loading ? [] : [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                      ),
                                      child: _loading
                                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                          : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('Sign In', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 32),
                                Text('Contact the Super Admin if you need access.', style: GoogleFonts.inter(fontSize: 13, color: _subtextColor(context)), textAlign: TextAlign.center),
                              ]
                          ),
                        ),
                      ),
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