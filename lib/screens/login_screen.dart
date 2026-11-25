// LOGIN — the front door.
//
// Three ways in, in order of how much commitment they need:
//  1. "Try the demo — no password needed": the full app with sample data,
//     read-only. Nothing the visitor does is saved. This is the button the
//     portfolio demo link lands on.
//  2. Sign in with a local account (email + password).
//  3. Create a local account (email + password, at least 10 characters).
//
// The lockout lives here in the UI as a message ("try again in X min"),
// but it is ENFORCED in AuthService — the screen cannot bypass it.

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});

  final AppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = _isSignUp
        ? await widget.state.signUp(
            _emailController.text,
            _passwordController.text,
          )
        : await widget.state.signIn(
            _emailController.text,
            _passwordController.text,
          );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.ok ? null : result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            const Text('🏋️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Self-Improvement',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Turn a good habit into a hobby. '
              'Your progress, your XP, your streak — all in one place.',
            ),
            const SizedBox(height: 32),
            // ── Demo first: no password, no account, no commitment ───────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.state.enterDemo,
                icon: const Icon(Icons.play_circle_outline),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Try the demo — no password needed'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Demo mode opens the full app with sample data. '
              'It is read-only — nothing you do there is saved, '
              'and no real user data is ever shown.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 32),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or use your account'),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: _isSignUp
                    ? 'At least 10 characters'
                    : 'Your password',
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.roseSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.rose,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy
                    ? 'Please wait…'
                    : _isSignUp
                        ? 'Create account'
                        : 'Sign in'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _isSignUp = !_isSignUp;
                _error = null;
              }),
              child: Text(
                _isSignUp
                    ? 'Already have an account? Sign in'
                    : 'New here? Create an account',
              ),
            ),
            const SizedBox(height: 24),
            const AppCard(
              child: Text(
                'Your account lives on this phone in v1 — passwords are '
                'salted and hashed, never stored in plain text, and your '
                'session token lives in secure storage. After 5 wrong '
                'passwords the account locks for 15 minutes. '
                'When Firebase is connected, sign-in moves to Firebase Auth.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
