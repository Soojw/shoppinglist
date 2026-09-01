import 'package:flutter/material.dart';
import '../services/database_service.dart';

class NotificationPreferencesPage extends StatefulWidget {
  final String userEmail;

  const NotificationPreferencesPage({super.key, required this.userEmail});

  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  bool _priceDropAlerts = true;
  bool _ticketUpdates = true;
  bool _promotionalOffers = true;
  bool _announcements = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final users = await DatabaseService().getAllUsers();
    try {
      final currentUser = users.firstWhere((u) => u['email'] == widget.userEmail);
      setState(() {
        _priceDropAlerts = currentUser['wants_price_drop'] == 1;
        _ticketUpdates = currentUser['wants_order_updates'] == 1;
        _promotionalOffers = currentUser['wants_promotions'] == 1;

        _announcements = currentUser['wants_newsletter'] == 1;

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _savePreference(String uiName, String dbColumnName, bool value) async {
    int intValue = value ? 1 : 0;
    await DatabaseService().updateNotificationPreference(widget.userEmail, dbColumnName, intValue);

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$uiName updated in database.'),
          duration: const Duration(milliseconds: 800),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color deepSlate = Color(0xFF1E293B);
    const Color primaryGreen = Color(0xFF059669);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Notification Preferences', style: TextStyle(color: deepSlate, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: deepSlate),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Control what you want to hear about. We will never spam you.', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 32),

            const Text('Shopping Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: deepSlate)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: primaryGreen,
                    title: const Text('Price Drop Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _priceDropAlerts,
                    onChanged: (value) {
                      setState(() => _priceDropAlerts = value);
                      _savePreference('Price Drop Alerts', 'wants_price_drop', value);
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    activeColor: primaryGreen,
                    title: const Text('Support Ticket Updates', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _ticketUpdates,
                    onChanged: (value) {
                      setState(() => _ticketUpdates = value);
                      _savePreference('Support Ticket Updates', 'wants_order_updates', value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            const Text('Promotions & Announcements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: deepSlate)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: primaryGreen,
                    title: const Text('Promotional Offers', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _promotionalOffers,
                    onChanged: (value) {
                      setState(() => _promotionalOffers = value);
                      _savePreference('Promotions', 'wants_promotions', value);
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  SwitchListTile(
                    activeColor: primaryGreen,
                    title: const Text('System Announcements', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _announcements,
                    onChanged: (value) {
                      setState(() => _announcements = value);
                      _savePreference('System Announcements', 'wants_newsletter', value);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}