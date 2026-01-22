import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Custom exception for timeout errors
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}

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
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _errorMessage;
  Future<void> _signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: use Firebase popup (no google_sign_in plugin)
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile'); // ensure name/photo are available

        await _auth.signInWithPopup(googleProvider);

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      }

      // Mobile (Android/iOS): Use google_sign_in plugin
      final GoogleSignIn googleSignIn = GoogleSignIn(
        // Request both email and profile to keep displayName/photoURL populated
        scopes: ['email', 'profile'],
      );

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return;
      }

      // Obtain auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential for Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      await _auth.signInWithCredential(credential);

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = 'Google sign-in failed';
      
      // Provide specific error messages
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = 'An account already exists with this email.';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Invalid credentials. Please try again.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed: ${e.toString()}'),
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'Login request timed out. Please check your internet connection.',
            ),
          );

      if (!mounted) return;

      // ✅ Success → go to home
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please try again.';

      if (e.code == 'user-not-found') {
        message = 'No account found with this email. Please sign up instead.';
      } else if (e.code == 'wrong-password') {
        message =
            'Incorrect password. Please try again or reset your password.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many failed login attempts. Please try again later.';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled.';
      }

      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    } on TimeoutException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'An unexpected error occurred. Please check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  void _goToForgotPassword() {
    Navigator.of(context).pushNamed('/forgot-password');
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
                    border: Border.all(
                      color: kCardBorder.withAlpha((0.2 * 255).round()),
                    ),
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
                            Text(
                              'Welcome back!',
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(
                                    fontFamily: 'Poppins',
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: kPrimaryText,
                                  ) ??
                                  const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: kPrimaryText,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Log in to continue walking with Yalla Nemshi',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    height: 1.55,
                                    color: kSecondaryText.withAlpha(
                                      (0.78 * 255).round(),
                                    ),
                                  ) ??
                                  TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    height: 1.55,
                                    color: kSecondaryText.withAlpha(
                                      (0.78 * 255).round(),
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 24),
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _buildLabeledField(
                                    label: 'Email',
                                    icon: Icons.email_outlined,
                                    controller: _emailController,
                                    validator: _validateEmail,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLabeledField(
                                    label: 'Password',
                                    icon: Icons.lock_outline,
                                    controller: _passwordController,
                                    validator: _validatePassword,
                                    obscureText: true,
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _goToForgotPassword,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        foregroundColor: kSecondaryText
                                            .withAlpha((0.8 * 255).round()),
                                        textStyle: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                      child: const Text('Forgot Password?'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _GradientButton(
                                    text: 'Sign in',
                                    onPressed: _isLoading ? null : _login,
                                    isLoading: _isLoading,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: kSecondaryText.withAlpha(
                                      (0.2 * 255).round(),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: Text(
                                    'or continue with',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: kSecondaryText.withAlpha(
                                            (0.7 * 255).round(),
                                          ),
                                        ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: kSecondaryText.withAlpha(
                                      (0.2 * 255).round(),
                                    ),
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
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: kSecondaryText.withAlpha(
                                          (0.7 * 255).round(),
                                        ),
                                      ),
                                ),
                                TextButton(
                                  onPressed: _goToSignup,
                                  style: TextButton.styleFrom(
                                    foregroundColor: kSignUpAccent,
                                    textStyle: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
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
    required String? Function(String?)? validator,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: kSecondaryText.withAlpha((0.8 * 255).round()),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: !_isLoading,
          validator: validator,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: kPrimaryText,
          ),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              color: kHintText.withAlpha((0.5 * 255).round()),
            ),
            prefixIcon: Icon(
              icon,
              color: kIconColor.withAlpha((0.9 * 255).round()),
            ),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.3),
            ),
            errorStyle: const TextStyle(
              fontFamily: 'Inter',
              color: Colors.red,
              fontSize: 12,
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
  final VoidCallback? onPressed;
  final bool isLoading;

  const _GradientButton({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLoading
              ? [
                  Colors.grey.withValues(alpha: 0.5),
                  Colors.grey.withValues(alpha: 0.5),
                ]
              : const [kButtonGradientStart, kButtonGradientEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: kPrimaryText,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                )
              : Text(
                  text,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ) ??
                      const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                        color: Colors.white,
                      ),
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
    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
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
              border: Border.all(
                color: kSocialGlassBorder.withAlpha((0.2 * 255).round()),
              ),
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
      ),
    );
  }
}
