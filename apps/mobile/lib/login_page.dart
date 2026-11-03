// Sign in to SABA per mockup 02. Purely dummy UI: tapping Sign in goes
// straight to the home screen (pop), no backend auth.
import 'package:flutter/material.dart';

import 'saba_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  bool _showPass = false;
  bool _remember = false;

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _soon(String what) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what needs backend auth')));
  }

  InputDecoration _fieldDec({
    required String hint,
    required IconData prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: SabaColors.muted2),
      prefixIcon: Icon(prefix, size: 18, color: SabaColors.muted2),
      suffixIcon: suffix,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: SabaColors.primary, width: 1.5),
      ),
      isDense: true,
      filled: true,
      fillColor: SabaColors.greyFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SabaColors.bgWarm,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            // Logo.
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: SabaColors.borderSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'S',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: SabaColors.primary,
                      ),
                    ),
                  ),
                  const Positioned(
                    right: -6,
                    bottom: -6,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: SabaColors.primary,
                      child: Icon(
                        Icons.graphic_eq,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: SabaColors.chipBlueBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'DISCUSSION • OPINION • ESSAYS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SabaColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'SABA',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
            ),
            const Center(
              child: Text(
                'A Dialogue & Community Space\nVerified Knowledge',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: SabaColors.muted2),
              ),
            ),
            const SizedBox(height: 20),
            // Email.
            const Row(
              children: [
                Text(
                  'Email or Username',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Spacer(),
                Text(
                  'Author ID / Account',
                  style: TextStyle(fontSize: 11, color: SabaColors.muted2),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _id,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDec(
                hint: 'you@saba.id or @your_name',
                prefix: Icons.alternate_email,
              ),
            ),
            const SizedBox(height: 12),
            // Password.
            Row(
              children: [
                const Text(
                  'Password',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _soon('Forgot password'),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SabaColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _pass,
              obscureText: !_showPass,
              decoration: _fieldDec(
                hint: 'Enter your account password',
                prefix: Icons.lock_outline,
                suffix: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _showPass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  color: SabaColors.muted2,
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _remember = !_remember),
              child: Row(
                children: [
                  Checkbox(
                    value: _remember,
                    activeColor: SabaColors.primary,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) => setState(() => _remember = v ?? false),
                  ),
                  const Text(
                    'Remember me on this device',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Sign in (dummy: goes back immediately).
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign in to SABA',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider(color: SabaColors.borderSoft)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'OR CONTINUE WITH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SabaColors.muted2,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: SabaColors.borderSoft)),
              ],
            ),
            const SizedBox(height: 12),
            _socialButton(
              'G',
              'Continue with Google',
              () => _soon('Continue with Google'),
            ),
            const SizedBox(height: 8),
            _socialButton(
              '',
              'Continue with Apple',
              () => _soon('Continue with Apple'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SabaColors.chipBlueBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: SabaColors.body,
                  ),
                  children: [
                    TextSpan(
                      text: 'Collaborative Intellect.\n',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: SabaColors.ink,
                      ),
                    ),
                    TextSpan(
                      text:
                          'Civil discussion grounded in trusted references. Join tens of thousands of independent thinkers.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('New to SABA? ', style: TextStyle(fontSize: 13)),
                GestureDetector(
                  onTap: () => _soon('Sign up'),
                  child: const Text(
                    'Sign Up Now',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: SabaColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Open Community, Free of Hoaxes',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'By signing in, you agree to SABA\u2019s Terms of Service, Community Guidelines, and Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: SabaColors.muted2),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _socialButton(String glyph, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: SabaColors.greyFill,
          foregroundColor: SabaColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              glyph,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
