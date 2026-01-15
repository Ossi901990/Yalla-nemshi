import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_user_service.dart';
import '../services/crash_service.dart';

/// ===== SAME COLOR PALETTE AS LOGIN =====
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

class SignupScreen extends StatefulWidget {
  static const routeName = '/signup';

  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await cred.user?.updateDisplayName(name);

      // ✅ Create user profile in Firestore (with error handling)
      if (cred.user != null) {
        try {
          await FirestoreUserService.createUser(
            uid: cred.user!.uid,
            email: email,
            displayName: name,
          );
          debugPrint('✅ Firestore user created successfully');
        } catch (firestoreError) {
          debugPrint('❌ Firestore creation error: $firestoreError');
          CrashService.recordError(
            firestoreError,
            StackTrace.current,
            reason: 'Failed to create Firestore user on signup',
          );
          
          // Don't block signup even if Firestore fails
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created but profile sync failed. Please retry profile setup.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      // ✅ Success → go to home
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      // Show full error while we debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign up failed: [${e.code}] ${e.message ?? ''}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
          ),
        );
      }
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _onSocialTap(String provider) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$provider sign-up coming soon ✨')));
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

          // 🔹 Content (title + bottom sheet card)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Small back button
                    IconButton(
                      onPressed: _goToLogin,
                      padding: EdgeInsets.zero,
                      tooltip: 'Go back',
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: kPrimaryText,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Create account",
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall?.copyWith(
                            fontFamily: 'Poppins',
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: kPrimaryText) ??
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
                      "Join Yalla Nemshi and start walking with others.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.55,
                        color: kSecondaryText.withAlpha((0.78 * 255).round()),
                      ) ??
                          TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.55,
                            color: kSecondaryText.withAlpha((0.78 * 255).round()),
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

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
                            // Name
                            _buildLabeledField(
                              label: 'Full name',
                              icon: Icons.person_outline,
                              controller: _nameController,
                            ),
                            const SizedBox(height: 16),

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
                            const SizedBox(height: 16),

                            // Confirm Password
                            _buildLabeledField(
                              label: 'Confirm password',
                              icon: Icons.lock_outline,
                              controller: _confirmController,
                              obscureText: true,
                            ),

                            const SizedBox(height: 16),

                            _GradientButton(
                              text: 'Create account',
                              onPressed: _register,
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
                                    'or sign up with',
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
                                  tooltip: 'Sign up with Google',
                                  onTap: () => _onSocialTap('Google'),
                                ),
                                _SocialIconButton(
                                  icon: Icons.mail_outline,
                                  tooltip: 'Sign up with Microsoft',
                                  onTap: () => _onSocialTap('Microsoft'),
                                ),
                                _SocialIconButton(
                                  icon: Icons.apple,
                                  tooltip: 'Sign up with Apple',
                                  onTap: () => _onSocialTap('Apple'),
                                ),
                                _SocialIconButton(
                                  icon: Icons.facebook,
                                  tooltip: 'Sign up with Facebook',
                                  onTap: () => _onSocialTap('Facebook'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Already have an account? ",
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: kSecondaryText.withAlpha(
                                          (0.7 * 255).round(),
                                        ),
                                      ),
                                ),
                                TextButton(
                                  onPressed: _goToLogin,
                                  style: TextButton.styleFrom(
                                    foregroundColor: kSignUpAccent,
                                    textStyle: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                  child: const Text('Sign in'),
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
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: kSecondaryText.withAlpha((0.8 * 255).round()),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
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
          ),
        ),
      ],
    );
  }
}

/// Gradient button reused from login
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
        height: 52,
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
            child: Icon(
              icon, // ✅ use the icon passed in
              color: kPrimaryText,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
