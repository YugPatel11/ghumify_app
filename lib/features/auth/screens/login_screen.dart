import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/premium_background.dart';
import '../../../core/widgets/premium_card.dart';

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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: PremiumBackground(
        imageUrl: 'https://images.unsplash.com/photo-1514222288955-4309322ebbc1?q=80&w=2000&auto=format&fit=crop', // Stunning nature aesthetic
        imageHeight: MediaQuery.of(context).size.height,
        overlayOpacity: 0.4,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: PremiumCard(
                    padding: const EdgeInsets.all(AppTokens.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppTokens.md),
                        // ── Editorial Branding ──
                        Text(
                          'GHUMIFY',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 4.0,
                          ),
                        ),
                        const SizedBox(height: AppTokens.md),
                        Text(
                          'Welcome\nBack.',
                          style: Theme.of(context).textTheme.displayMedium,
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
                                decoration: const InputDecoration(
                                  hintText: 'Email address',
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
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: AppColors.textSoft,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
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

                              // Login button (Solid Editorial)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.text, // Solid Charcoal
                                    padding: const EdgeInsets.symmetric(vertical: 24),
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
                                      : const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppTokens.xl),

                        // ── Divider ──
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),

                        const SizedBox(height: AppTokens.xl),

                        // ── Google Sign In ──
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: isLoading ? null : _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.borderLight, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 22),
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
                                Text('Continue with Google', style: Theme.of(context).textTheme.titleSmall),
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
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            GestureDetector(
                              onTap: () => context.go('/signup'),
                              child: Text(
                                'Sign Up',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: AppColors.text,
                                      decoration: TextDecoration.underline,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.md),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        backgroundColor: AppColors.card,
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
              decoration: const InputDecoration(
                hintText: 'Email address',
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
                      backgroundColor: AppColors.text,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.text, foregroundColor: Colors.white),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
