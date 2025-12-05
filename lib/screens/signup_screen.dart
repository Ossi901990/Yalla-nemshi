import 'dart:ui';
import 'package:flutter/material.dart';

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
const kButtonGradientEnd = Color(0xFFFD7F5E);   // orange

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _register() {
    // TODO: replace with real Firebase sign up
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _onSocialTap(String provider) {
    // TODO: hook to Google / Microsoft / Facebook / Apple
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider sign-up coming soon ✨')),
    );
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
                    kBgTop.withOpacity(0.7),
                    kBgMid.withOpacity(0.85),
                    kBgBottom.withOpacity(0.9),
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
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: kPrimaryText,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Create account",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Join Yalla Nemshi and start walking with others.",
                      style: TextStyle(
                        fontSize: 13,
                        color: kSecondaryText.withOpacity(0.7),
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
                        color: kCardOverlay.withOpacity(0.45),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                        border: Border.all(
                          color: kCardBorder.withOpacity(0.15),
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
                                    color:
                                        kSecondaryText.withOpacity(0.2),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Text(
                                    'or sign up with',
                                    style: TextStyle(
                                      color: kSecondaryText
                                          .withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color:
                                        kSecondaryText.withOpacity(0.2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
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
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Already have an account? ",
                                  style: TextStyle(
                                    color: kSecondaryText
                                        .withOpacity(0.7),
                                    fontSize: 13,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _goToLogin,
                                  style: TextButton.styleFrom(
                                    foregroundColor: kSignUpAccent,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
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
          style: TextStyle(
            color: kSecondaryText.withOpacity(0.8),
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
            hintStyle: TextStyle(
              color: kHintText.withOpacity(0.5),
            ),
            prefixIcon: Icon(
              icon,
              color: kIconColor.withOpacity(0.9),
            ),
            filled: true,
            fillColor: kFieldFill.withOpacity(0.06),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: kFieldBorder.withOpacity(0.15),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: kFieldBorder.withOpacity(0.8),
                width: 1.3),
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
          colors: [
            kButtonGradientStart,
            kButtonGradientEnd,
          ],
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
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
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
            color: kSocialGlassFill.withOpacity(0.08),
            border: Border.all(
              color: kSocialGlassBorder.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: kSocialShadow.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            color: kPrimaryText,
            size: 22,
          ),
        ),
      ),
    );
  }
}
