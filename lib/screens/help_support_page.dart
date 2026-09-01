import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';
import '../services/database_service.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {

  void _showSubmitTicketSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SubmitTicketForm(),
    );
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
        title: const Text('Help & Support', style: TextStyle(color: deepSlate, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: deepSlate),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(16)),
              child: const Column(
                children: [
                  Icon(Icons.support_agent, size: 48, color: primaryGreen),
                  SizedBox(height: 12),
                  Text('How can we help you?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                ],
              ),
            ),
            const SizedBox(height: 32),

            const Text('Frequently Asked Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: deepSlate)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: const Column(
                children: [
                  ExpansionTile(
                    title: Text('Are the prices 100% accurate?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('We sync our data daily. However, physical store prices may fluctuate. Please treat our prices as a highly accurate reference. Final pricing is decided by the cashier.', style: TextStyle(color: Colors.grey, height: 1.5)),
                      )
                    ],
                  ),
                  ExpansionTile(
                    title: Text('How does Targeted Push work?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('When you tap the heart icon on a product, you opt-in for alerts. If that item drops in price at a nearby store, our engine will notify you immediately.', style: TextStyle(color: Colors.grey, height: 1.5)),
                      )
                    ],
                  ),
                  ExpansionTile(
                    title: Text('Found a wrong price?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Help our community by reporting it! Click on "Report Issue" in the product details page to submit a correction.', style: TextStyle(color: Colors.grey, height: 1.5)),
                      )
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),


            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _showSubmitTicketSheet,
                icon: const Icon(Icons.edit_document, color: Colors.white),
                label: const Text('Submit an Inquiry / Issue', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubmitTicketForm extends StatefulWidget {
  const SubmitTicketForm({super.key});

  @override
  State<SubmitTicketForm> createState() => _SubmitTicketFormState();
}

class _SubmitTicketFormState extends State<SubmitTicketForm> {
  final TextEditingController _descController = TextEditingController();
  String _selectedCategory = 'General Inquiry';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'General Inquiry',
    'Report Incorrect Price',
    'App Bug / Error',
    'Account Issue',
    'Feature Suggestion'
  ];


  void _submitTicket() async {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please describe your issue first.'), backgroundColor: Colors.redAccent)
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String userEmail = userProvider.isLoggedIn ? userProvider.userEmail : 'guest@smartshopping.com';

    await DatabaseService().submitTicket(
        userEmail,
        _selectedCategory,
        _descController.text.trim()
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Color(0xFF059669)),
              const SizedBox(height: 16),
              const Text('Ticket Submitted!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Thank you for reaching out. Our support team will review your $_selectedCategory shortly.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color deepSlate = Color(0xFF1E293B);
    const Color primaryGreen = Color(0xFF059669);


    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Submit a Ticket', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: deepSlate)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            ],
          ),
          const SizedBox(height: 24),

          const Text('Issue Category', style: TextStyle(fontWeight: FontWeight.w600, color: deepSlate)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                items: _categories.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type, style: const TextStyle(fontWeight: FontWeight.w500, color: deepSlate)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedCategory = newValue!);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, color: deepSlate)),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Please describe your issue or question in detail...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}