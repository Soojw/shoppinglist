import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_page.dart';
import '../services/user_login_page.dart';
import '../services/database_service.dart';
import 'account_settings_page.dart';
import 'notification_preferences_page.dart';
import 'location_services_page.dart';
import 'help_support_page.dart';
import '../services/user_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isUserLoggedIn = false;

  String currentUserName = 'Guest User';
  String currentUserEmail = '';
  String currentUserId = 'Not logged in';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.isLoggedIn) {
        setState(() {
          isUserLoggedIn = true;
          currentUserName = userProvider.userName;
          currentUserEmail = userProvider.userEmail;
          currentUserId = 'ID: Active User';
        });
      }
    });
  }

  Future<void> _fetchUserData() async {
    final users = await DatabaseService().getAllUsers();
    if (users.isNotEmpty) {
      final latestUser = users.first;
      setState(() {
        currentUserName = latestUser['name'];
        currentUserEmail = latestUser['email'];
        currentUserId = 'ID: 8092-${latestUser['id'].toString().padLeft(4, '0')}';
      });
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).login(currentUserEmail, currentUserName);
      }
    } else {
      setState(() {
        currentUserName = 'SmartConsumer';
        currentUserEmail = 'user@smartshopping.com';
        currentUserId = 'ID: 8092-2345';
      });
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).login(currentUserEmail, currentUserName);
      }
    }
  }

  void _handleAccountSettingsTap() async {
    if (isUserLoggedIn) {
      final loggedOut = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AccountSettingsPage(
            userName: currentUserName,
            userId: currentUserId,
            userEmail: currentUserEmail,
          ),
        ),
      );

      if (loggedOut == true) {
        setState(() {
          isUserLoggedIn = false;
          currentUserName = 'Guest User';
          currentUserEmail = '';
          currentUserId = 'Not logged in';
        });

        if (context.mounted) {
          Provider.of<UserProvider>(context, listen: false).logout();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out successfully.')));
        }
      }
    } else {
      _showLoginRegisterPrompt();
    }
  }

  void _showLoginRegisterPrompt() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            const Icon(Icons.account_circle, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Sign In Required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Log in or create an account to view and manage your profile details.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserLoginPage()),
                  );

                  if (result == true) {
                    await _fetchUserData();
                    setState(() {
                      isUserLoggedIn = true;
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Welcome back, $currentUserName! ✨'), backgroundColor: const Color(0xFF059669))
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Go to Login / Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF059669);
    const Color deepSlate = Color(0xFF1E293B);

    final Color headerColor = isUserLoggedIn ? primaryGreen : Colors.grey.shade400;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 32),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MY PROFILE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.person, size: 36, color: Colors.white),
                        ),
                        if (isUserLoggedIn)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.verified, size: 16, color: primaryGreen),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUserName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(currentUserId, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('System Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: deepSlate)),
                  const SizedBox(height: 16),

                  _buildMenuTile(
                    icon: Icons.person_outline,
                    title: 'Account Settings',
                    onTap: _handleAccountSettingsTap,
                  ),

                  _buildMenuTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notification Preferences',
                    onTap: () {
                      if (isUserLoggedIn) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => NotificationPreferencesPage(
                                userEmail: currentUserEmail,
                              )
                          ),
                        );
                      } else {
                        _showLoginRegisterPrompt();
                      }
                    },
                  ),

                  _buildMenuTile(
                      icon: Icons.location_on_outlined,
                      title: 'Location Services',
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const LocationServicesPage()));
                      }
                  ),

                  _buildMenuTile(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpSupportPage()));
                      }
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (isUserLoggedIn) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please Sign Out from your Member account first.'),
                                backgroundColor: Colors.redAccent,
                                duration: Duration(seconds: 2),
                              )
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        }
                      },
                      icon: const Icon(Icons.login, color: deepSlate),
                      label: const Text('Admin / Staff Login', style: TextStyle(color: deepSlate, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({required IconData icon, required String title, VoidCallback? onTap}) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.grey.shade700),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: onTap,
        ),
        Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }
}