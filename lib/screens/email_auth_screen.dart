import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'role_selection_screen.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  bool _isLogin = true;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      return _showMessage('Enter email and password');
    }
    if (!_isLogin && password != _confirmCtrl.text) {
      return _showMessage('Passwords do not match');
    }

    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      if (_isLogin) {
        await auth.signInWithEmail(email: email, password: password);
        if (!mounted) return;
        _showMessage('Signed in successfully');
        // Close the EmailAuthScreen so the root AuthGate StreamBuilder can react
        Navigator.of(context).pop();
      } else {
        await auth.registerWithEmail(email: email, password: password);
        // After successful registration, navigate to role selection
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          (route) => false,
        );
      }
      // On success the AuthGate will react to authState and navigate.
    } catch (e) {
      _showMessage('Auth error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Sign in with Email' : 'Sign up'),
        backgroundColor: AppColors.primary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isLogin ? 'Sign In' : 'Create Account'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                        _isLogin = !_isLogin;
                      }),
                child: Text(
                  _isLogin
                      ? 'Don\'t have an account? Sign up'
                      : 'Already have an account? Sign in',
                ),
              ),
              if (_isLogin) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final email = _emailCtrl.text.trim();
                    if (email.isEmpty) {
                      return _showMessage('Enter your email to reset password');
                    }
                    setState(() => _loading = true);
                    try {
                      final auth = Provider.of<AuthService>(
                        context,
                        listen: false,
                      );
                      await auth.sendPasswordReset(email: email);
                      _showMessage('Password reset sent to $email');
                    } catch (e) {
                      _showMessage('Reset failed: $e');
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
                  child: const Text('Forgot password?'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
