import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/app_image.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<Offset> _parallaxAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );
    _parallaxAnim = Tween<Offset>(
      begin: const Offset(0.05, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutSine),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      context.go('/home');
    } else if (mounted && authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error!, style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
        ),
      );
      authProvider.clearError();
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();

    if (success && mounted) {
      context.go('/home');
    } else if (mounted && authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error!, style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
        ),
      );
      authProvider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Moving Parallax Background ──
          SlideTransition(
            position: _parallaxAnim,
            child: SizedBox(
              width: size.width * 1.1,
              height: size.height,
              child: const AppImage(
                imageUrl: 'https://images.unsplash.com/photo-1598889151208-c2b64dff5421?q=80&w=1200&auto=format&fit=crop', // Taj Mahal / India heritage
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // ── Elegant Overlay ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.brandDeep.withOpacity(0.3),
                    AppColors.brandDeep.withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Container(
                      padding: const EdgeInsets.all(AppTokens.xl),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated, // Solid premium white
                        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppTokens.sm),
                          // ── Branding ──
                          Text(
                            'GHUMIFY',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.accent,
                              letterSpacing: 4.0,
                            ),
                          ),
                          const SizedBox(height: AppTokens.md),
                          Text(
                            'Begin your\njourney.',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: AppColors.brandDeep,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppTokens.xl),

                          // ── Form ──
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    hintText: 'Email address',
                                    fillColor: AppColors.cardAlt,
                                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                                      borderSide: const BorderSide(color: AppColors.brand, width: 2),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppTokens.md),

                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _handleLogin(),
                                  style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    hintText: 'Password',
                                    fillColor: AppColors.cardAlt,
                                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: AppColors.textMuted,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                                      borderSide: const BorderSide(color: AppColors.brand, width: 2),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppTokens.sm),

                                // Forgot password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.textSoft,
                                    ),
                                    child: const Text('Forgot Password?'),
                                  ),
                                ),
                                const SizedBox(height: AppTokens.lg),

                                // Login button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.brand,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                                      ),
                                      elevation: 4,
                                      shadowColor: AppColors.brand.withOpacity(0.4),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppTokens.xl),

                          // ── Divider ──
                          Row(
                            children: [
                              Expanded(child: Divider(color: AppColors.border)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                                ),
                              ),
                              Expanded(child: Divider(color: AppColors.border)),
                            ],
                          ),

                          const SizedBox(height: AppTokens.xl),

                          // ── Google Sign In ──
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: isLoading ? null : _handleGoogleSignIn,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                    height: 20,
                                    width: 20,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 28, color: AppColors.text),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('Continue with Google', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.text, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTokens.xl),

                          // ── Sign up link ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSoft),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/signup'),
                                child: Text(
                                  'Sign Up',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: AppColors.brand,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTokens.xs),
                        ],
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

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        backgroundColor: Colors.white,
        title: Text('Reset Password', style: Theme.of(context).textTheme.headlineSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your email to receive a password reset link.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTokens.md),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email address',
                fillColor: AppColors.cardAlt,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSoft),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isNotEmpty) {
                final authProvider = context.read<AuthProvider>();
                await authProvider.resetPassword(email);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset email sent!', style: TextStyle(color: Colors.white)),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: Colors.white),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
