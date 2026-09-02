import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../admin/admin_dashboard.dart';
import '../services/database_service.dart';
import '../services/user_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    final input = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter the username/email and password'), backgroundColor: Colors.redAccent)
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (input.toLowerCase() == 'admin' && password == 'admin') {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboard()),
                (Route<dynamic> route) => false,
          );
        }
        return;
      }

      final user = await DatabaseService().loginUser(input, password);

      if (user != null) {
        final userName = user['name'] ?? 'Smart Shopper';
        final userEmail = user['email'] ?? input;

        if (mounted) {
          Provider.of<UserProvider>(context, listen: false).login(userEmail, userName);

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Welcome back, $userName! ✨'), backgroundColor: const Color(0xFF059669))
          );

          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid credentials or account does not exist.'), backgroundColor: Colors.redAccent)
          );
        }
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('An error occurred during login.'), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF059669);
    const Color deepSlate = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: deepSlate),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.shopping_cart_checkout, size: 48, color: primaryGreen),
              ),
              const SizedBox(height: 24),
              const Text('Welcome to\nSmart Shopping.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: deepSlate, height: 1.2)),
              const SizedBox(height: 8),
              const Text('Log in to continue to your account.', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 40),

              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'Email or Mobile Number',
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}