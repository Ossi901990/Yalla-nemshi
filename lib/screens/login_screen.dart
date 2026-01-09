import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ===== COLOR PALETTE =====
const kBgTop = Color(0xFF04120B);
const kBgMid = Color(0xFF062219);
const kBgBottom = Color(0xFF0C3624);

const kCardOverlay = Colors.black;
const kCardBorder = Colors.white;

const kPrimaryText = Colors.white;
const kSecondaryText = Colors.white;
const kHintText = Colors.white;
const kIconColor = Colors.white;

const kButtonGradientStart = Color(0xFFFD5E77); // pink
const kButtonGradientEnd = Color(0xFFFD7F5E); // orange

const kSignUpAccent = Color(0xFFF86C81);

const kFieldFill = Colors.white;
const kFieldBorder = Colors.white;

const kSocialGlassFill = Colors.white;
const kSocialGlassBorder = Colors.white;
const kSocialShadow = Colors.black;

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<void> _signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: use Firebase popup (no google_sign_in plugin)
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');

        await _auth.signInWithPopup(googleProvider);

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      }

      // Non-web: Google sign-in disabled for now (keep mobile changes undone)
      if (!kIsWeb) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in is available on web only for now.'),
          ),
        );
        return;
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: ${e.message ?? ''}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google sign-in failed. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (!mounted) return;

      // ✅ Success → go to home
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please try again.';

      if (e.code == 'user-not-found') {
        message = 'No user found with that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password. Please try again.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An unexpected error occurred. Please try again.'),
        ),
      );
    }
  }

  void _goToSignup() {
    Navigator.of(context).pushNamed('/signup');
  }

  void _onSocialTap(String provider) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$provider sign-in coming soon ✨')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔹 Background image behind everything
          Positioned.fill(
            child: Image.asset(
              'assets/images/walk_group.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // 🔹 Semi-transparent dark gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kBgTop.withAlpha((0.7 * 255).round()),
                    kBgMid.withAlpha((0.85 * 255).round()),
                    kBgBottom.withAlpha((0.9 * 255).round()),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 🔹 Content (top icon + bottom sheet card)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),

              // Top circle icon
              Center(
                child: Container(
                  height: 110,
                  width: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kCardOverlay.withAlpha((0.35 * 255).round()),
                    border: Border.all(color: kCardBorder.withAlpha((0.2 * 255).round())),
                  ),
                  child: const Icon(
                    Icons.directions_walk,
                    size: 56,
                    color: kIconColor,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Glass card that fills downwards
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      decoration: BoxDecoration(
                        color: kCardOverlay.withAlpha((0.45 * 255).round()),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                        border: Border.all(
                          color: kCardBorder.withAlpha((0.15 * 255).round()),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Welcome back!',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Log in to continue walking with Yalla Nemshi',
                              style: TextStyle(
                                fontSize: 13,
                                color: kSecondaryText.withAlpha((0.7 * 255).round()),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Email
                            _buildLabeledField(
                              label: 'Email',
                              icon: Icons.email_outlined,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),

                            // Password
                            _buildLabeledField(
                              label: 'Password',
                              icon: Icons.lock_outline,
                              controller: _passwordController,
                              obscureText: true,
                            ),

                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: kSecondaryText.withAlpha((0.8 * 255).round()),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                child: const Text('Forgot Password?'),
                              ),
                            ),

                            const SizedBox(height: 8),

                            _GradientButton(text: 'Sign in', onPressed: _login),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: kSecondaryText.withAlpha((0.2 * 255).round()),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: Text(
                                    'or continue with',
                                    style: TextStyle(
                                      color: kSecondaryText.withAlpha((0.7 * 255).round()),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: kSecondaryText.withAlpha((0.2 * 255).round()),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _SocialIconButton(
                                  icon: Icons.g_mobiledata,
                                  tooltip: 'Sign in with Google',
                                  onTap: _signInWithGoogle,
                                ),
                                _SocialIconButton(
                                  icon: Icons.mail_outline,
                                  tooltip: 'Sign in with Microsoft',
                                  onTap: () => _onSocialTap('Microsoft'),
                                ),
                                _SocialIconButton(
                                  icon: Icons.apple,
                                  tooltip: 'Sign in with Apple',
                                  onTap: () => _onSocialTap('Apple'),
                                ),
                                _SocialIconButton(
                                  icon: Icons.facebook,
                                  tooltip: 'Sign in with Facebook',
                                  onTap: () => _onSocialTap('Facebook'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don’t have an account? ",
                                  style: TextStyle(
                                    color: kSecondaryText.withAlpha((0.7 * 255).round()),
                                    fontSize: 13,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _goToSignup,
                                  style: TextButton.styleFrom(
                                    foregroundColor: kSignUpAccent,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  child: const Text('Sign up'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: kSecondaryText.withAlpha((0.8 * 255).round()),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: kPrimaryText),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(color: kHintText.withAlpha((0.5 * 255).round())),
            prefixIcon: Icon(icon, color: kIconColor.withAlpha((0.9 * 255).round())),
            filled: true,
            fillColor: kFieldFill.withAlpha((0.06 * 255).round()),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: kFieldBorder.withAlpha((0.15 * 255).round()),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: kFieldBorder.withAlpha((0.8 * 255).round()),
                width: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gradient pill button like the reference
class _GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _GradientButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kButtonGradientStart, kButtonGradientEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: kPrimaryText,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Glass-morphism social icon button
class _SocialIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SocialIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: kSocialGlassFill.withAlpha((0.08 * 255).round()),
            border: Border.all(color: kSocialGlassBorder.withAlpha((0.2 * 255).round())),
            boxShadow: [
              BoxShadow(
                color: kSocialShadow.withAlpha((0.4 * 255).round()),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: kPrimaryText, size: 22),
        ),
      ),
    );
  }
}


