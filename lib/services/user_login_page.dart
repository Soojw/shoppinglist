import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/register_page.dart';
import 'database_service.dart';
import 'user_provider.dart';

class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _resetEmailController = TextEditingController();

  static const Color primaryGreen = Color(0xFF059669);
  static const Color deepSlate = Color(0xFF1E293B);

  String? _emailErrorText;
  String? _passwordErrorText;

  bool _obscurePassword = true;

  bool _isValidUsername(String input) {
    final phoneRegex = RegExp(r'^\d{10,11}$');
    final emailRegex = RegExp(r'^.+@.+\.com$');
    return phoneRegex.hasMatch(input) || emailRegex.hasMatch(input);
  }

  bool _isValidPassword(String input) {
    return RegExp(r'^\d{3,}$').hasMatch(input);
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _emailErrorText = null;
      _passwordErrorText = null;
    });

    bool hasError = false;

    if (email.isEmpty) {
      setState(() => _emailErrorText = 'Email or mobile number is required.');
      hasError = true;
    } else if (!_isValidUsername(email)) {
      setState(() => _emailErrorText = 'Must be 10-11 digits or valid email (@ and .com).');
      hasError = true;
    }

    if (password.isEmpty) {
      setState(() => _passwordErrorText = 'Password is required.');
      hasError = true;
    } else if (!_isValidPassword(password)) {
      setState(() => _passwordErrorText = 'Must be at least 3 numbers.');
      hasError = true;
    }

    if (hasError) return;

    final users = await DatabaseService().getAllUsers();
    bool isMatchFound = false;
    String matchedName = 'Guest';

    for (var user in users) {
      if (user['email'] == email && user['password'] == password) {
        isMatchFound = true;
        matchedName = user['name'] ?? 'User';
        break;
      }
    }

    if (!isMatchFound) {
      setState(() {
        _passwordErrorText = 'Incorrect email/mobile or password.';
      });
      return;
    }

    if (context.mounted) {
      Provider.of<UserProvider>(context, listen: false).login(email, matchedName);
      Navigator.pop(context, true);
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your registered email or mobile number. We will send you a reset link.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: _resetEmailController,
              decoration: InputDecoration(
                hintText: 'Email or Mobile Number',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_resetEmailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an email or mobile number.'), backgroundColor: Colors.redAccent));
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset link sent! Please check your inbox.'), backgroundColor: primaryGreen));
              _resetEmailController.clear();
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text('Send Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: deepSlate),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.person_add_alt_1, size: 48, color: primaryGreen),
              ),
              const SizedBox(height: 24),
              const Text('Welcome Back to\nSmart Shopping.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: deepSlate, height: 1.2)),
              const SizedBox(height: 8),
              const Text('Log in to continue saving on your daily groceries.', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 40),

              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'Email or Mobile Number',
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  errorText: _emailErrorText,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,

                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Password (e.g. 123)',
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  errorText: _passwordErrorText,
                ),
              ),
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text('Forgot Password?', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterPage()),
                    );
                    if (result == true) {
                      if (context.mounted) Navigator.pop(context, true);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: primaryGreen, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Create New Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}