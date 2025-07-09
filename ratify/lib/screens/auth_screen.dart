import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ratify/services/auth_services.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _message = "";
  bool _loading = false;

  void _showMessage(String msg) {
    setState(() => _message = msg);
  }

  Future<void> _handleLogin() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (user != null) {
        _showMessage("Logged in as ${user.email}");
      }
    } on FirebaseAuthException catch (e) {
      _showMessage("Login failed: ${e.message}");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (user != null) {
        _showMessage("Account created for ${user.email}");
      }
    } on FirebaseAuthException catch (e) {
      _showMessage("Register failed: ${e.message}");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.signInWithGoogle();
      if (user != null) {
        _showMessage("Logged in with Google as ${user.email}");
      } else {
        _showMessage("Google login cancelled");
      }
    } catch (e) {
      _showMessage("Google login failed: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Ratify Login")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          children: [
            const Text(
              "Welcome to Ratify",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _handleLogin,
                    icon: const Icon(Icons.login),
                    label: const Text("Login"),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _handleRegister,
                    icon: const Icon(Icons.person_add),
                    label: const Text("Register"),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _handleGoogleLogin,
              icon: const Icon(Icons.account_circle),
              label: const Text("Continue with Google"),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                foregroundColor: isDark ? Colors.white : Colors.black87,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 20),
            if (_message.isNotEmpty)
              Text(
                _message,
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
