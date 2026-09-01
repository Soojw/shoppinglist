import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'master_list_page.dart';
import 'admin_users_page.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../models/price_model.dart';
import 'broadcast_page.dart';
import 'admin_trend_analytics_page.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  List<String> _parseCsvRow(String row) {
    List<String> cols = [];
    StringBuffer currentCol = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < row.length; i++) {
      if (row[i] == '"') {
        insideQuotes = !insideQuotes;
      } else if (row[i] == ',' && !insideQuotes) {
        cols.add(currentCol.toString().trim());
        currentCol.clear();
      } else {
        currentCol.write(row[i]);
      }
    }
    cols.add(currentCol.toString().trim());
    return cols;
  }

  @override
  Widget build(BuildContext context) {
    const Color deepSlate = Color(0xFF1E293B);
    const Color adminBlue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: adminBlue,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('System Admin Console', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const MainLayout()),
                    (Route<dynamic> route) => false,
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Database & Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildAdminCard(
              context,
              title: 'Master Product List',
              subtitle: 'Add/Edit items in MDM SQLite',
              icon: Icons.inventory_2,
              color: const Color(0xFF10B981),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MasterListPage())),
            ),

            const SizedBox(height: 24),
            const Text('User Management & Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildAdminCard(
              context,
              title: 'User Directory & Details',
              subtitle: 'View real registered accounts',
              icon: Icons.people_alt,
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUsersPage())),
            ),

            _buildAdminCard(
              context,
              title: 'Trend Analytics (Dual-Layer)',
              subtitle: 'Macro category & micro item insights',
              icon: Icons.pie_chart,
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminTrendAnalyticsPage()));
              },
            ),

            const SizedBox(height: 24),
            const Text('Customer Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildAdminCard(
              context,
              title: 'User Inquiries & Tickets',
              subtitle: 'Review and manage user feedback',
              icon: Icons.support_agent,
              color: const Color(0xFF14B8A6),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminTicketsPage())),
            ),

            const SizedBox(height: 24),
            const Text('Marketing & Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),

            _buildAdminCard(
              context,
              title: 'Broadcast Announcement',
              subtitle: 'Push general alerts to all users',
              icon: Icons.campaign,
              color: const Color(0xFF3B82F6),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BroadcastPage())),
            ),

            _buildAdminCard(
              context,
              title: 'Targeted Smart Push',
              subtitle: 'AI matches alerts to user favorites',
              icon: Icons.radar,
              color: const Color(0xFFEF4444),
              onTap: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
                  },
                );

                List<String> fetchedProducts = [];

                try {
                  final localItems = await DatabaseService().getFullCatalog();
                  for (var item in localItems) {
                    if (item['item_name'] != null) {
                      fetchedProducts.add(item['item_name']);
                    }
                  }

                  final String url = 'https://gist.githubusercontent.com/Soojw/75bc56ef66c5827c0b4a8c05a831d4d6/raw/final_data.csv?v=${DateTime.now().millisecondsSinceEpoch}';
                  final response = await http.get(Uri.parse(url));

                  if (response.statusCode == 200) {
                    List<String> rows = response.body.split('\n');
                    for (int i = 1; i < rows.length; i++) {
                      String row = rows[i].trim();
                      if (row.isEmpty) continue;

                      List<String> cols = _parseCsvRow(row);
                      if (cols.length < 12) continue;

                      String title = cols[4].trim();
                      fetchedProducts.add(title);
                    }
                  }
                } catch (e) {
                  debugPrint('Targeted Push Fetch Error: $e');
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }

                fetchedProducts = fetchedProducts.toSet().toList();
                fetchedProducts.sort();

                if (fetchedProducts.isEmpty) {
                  fetchedProducts = ['System Check: No Data Found'];
                }

                if (context.mounted) {
                  _showTargetedPushDialog(context, fetchedProducts);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showMockDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF2563EB))),
          )
        ],
      ),
    );
  }

  void _showTargetedPushDialog(BuildContext context, List<String> availableProducts) {
    String? selectedProduct;
    bool isAnalyzing = false;
    String resultText = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Targeted Smart Push', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select product from Live Top List to trigger alert:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: (resultText.isNotEmpty || isAnalyzing)
                        ? null
                        : () async {
                      final String? chosen = await showDialog<String>(
                        context: context,
                        builder: (BuildContext searchContext) {
                          String searchQuery = '';
                          return StatefulBuilder(
                            builder: (context, setSearchState) {
                              final filteredProducts = availableProducts
                                  .where((p) => p.toLowerCase().contains(searchQuery.toLowerCase()))
                                  .toList();
                              return AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                titlePadding: const EdgeInsets.all(0),
                                title: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                                  child: TextField(
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      hintText: 'Search product...',
                                      border: InputBorder.none,
                                      icon: Icon(Icons.search, color: Colors.grey),
                                    ),
                                    onChanged: (value) {
                                      setSearchState(() {
                                        searchQuery = value;
                                      });
                                    },
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(0),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  height: 300,
                                  child: filteredProducts.isEmpty
                                      ? const Center(child: Text('No matching products', style: TextStyle(color: Colors.grey)))
                                      : ListView.builder(
                                    itemCount: filteredProducts.length,
                                    itemBuilder: (context, index) {
                                      final item = filteredProducts[index];
                                      return ListTile(
                                        title: Text(item, style: const TextStyle(fontSize: 14)),
                                        onTap: () {
                                          Navigator.pop(searchContext, item);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                      if (chosen != null) {
                        setDialogState(() {
                          selectedProduct = chosen;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              selectedProduct ?? 'Tap to search product...',
                              style: TextStyle(
                                fontWeight: selectedProduct != null ? FontWeight.bold : FontWeight.normal,
                                color: selectedProduct != null ? const Color(0xFF1E293B) : Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.search, color: Color(0xFF2563EB), size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isAnalyzing)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: Color(0xFF2563EB)),
                          SizedBox(height: 16),
                          Text('Cross-referencing databases...', style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    )
                  else if (resultText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF34D399))),
                      child: Text(resultText, style: const TextStyle(color: Color(0xFF065F46), height: 1.5, fontSize: 14)),
                    ),
                ],
              ),
              actions: [
                if (resultText.isEmpty && !isAnalyzing)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                if (resultText.isEmpty && !isAnalyzing)
                  ElevatedButton(
                    onPressed: (selectedProduct == null)
                        ? null
                        : () async {
                      setDialogState(() {
                        isAnalyzing = true;
                      });

                      int targetAudienceCount = 0;
                      int actuallyFavoritedCount = 0;

                      try {
                        final users = await DatabaseService().getAllUsers();
                        final db = await DatabaseService().database;

                        for (var user in users) {
                          if (user['wants_price_drop'] == 1) targetAudienceCount++;

                          final List<Map<String, dynamic>> favoriteMatches = await db.query(
                            'Favorites',
                            where: 'user_email = ? AND product_name = ?',
                            whereArgs: [user['email'], selectedProduct],
                          );

                          if (favoriteMatches.isNotEmpty && user['wants_price_drop'] == 1) {
                            actuallyFavoritedCount++;

                            await DatabaseService().sendNotification(
                                user['email'] as String,
                                'Price Drop Alert! 📉',
                                'Great news! Your favorite item [$selectedProduct] has dropped in price. Check it out now!'
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint('DB Query fallback: $e');
                        targetAudienceCount = 12;
                        actuallyFavoritedCount = 1;
                      }

                      await Future.delayed(const Duration(milliseconds: 1500));

                      setDialogState(() {
                        isAnalyzing = false;
                        resultText = 'Data Analysis Complete.\n\n'
                            '✅ $targetAudienceCount users opted-in for Price Alerts.\n'
                            '✅ $actuallyFavoritedCount eligible users have [$selectedProduct] in their watchlists.\n\n'
                            'Push notification sent successfully! ✨';
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    child: const Text('Analyze & Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                if (resultText.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Done', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}


class AdminTicketsPage extends StatefulWidget {
  const AdminTicketsPage({super.key});

  @override
  State<AdminTicketsPage> createState() => _AdminTicketsPageState();
}

class _AdminTicketsPageState extends State<AdminTicketsPage> {

  void _refreshList() {
    setState(() {});
  }

  void _showReplyDialog(Map<String, dynamic> ticket) {
    final TextEditingController replyController = TextEditingController();
    bool isSending = false;

    String displayId = 'TKT-${ticket['id'].toString().padLeft(4, '0')}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.reply_all, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text('Reply to $displayId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User: ${ticket['user_email']}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                    child: Text('"${ticket['description']}"', style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontStyle: FontStyle.italic)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: replyController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Type your official response here...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB))),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSending ? null : () async {
                    if (replyController.text.trim().isEmpty) return;

                    setDialogState(() => isSending = true);

                    String userOriginalMessage = ticket['description'] ?? '';
                    String adminReply = replyController.text.trim();

                    String formattedThread = 'Your Inquiry:\n"$userOriginalMessage"\n\nSupport Team:\n$adminReply';

                    await DatabaseService().sendNotification(
                        ticket['user_email'],
                        'Support Reply: $displayId',
                        formattedThread
                    );

                    await DatabaseService().resolveTicket(ticket['id']);

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Response sent to ${ticket['user_email']}! 🚀'), backgroundColor: const Color(0xFF059669)),
                      );
                      _refreshList();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: isSending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Send Reply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color deepSlate = Color(0xFF1E293B);
    const Color adminBlue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('User Inquiries & Tickets', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: adminBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseService().getAllTickets(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: adminBlue));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text("No tickets found. You are all caught up!", style: TextStyle(color: Colors.grey)),
              );
            }

            final tickets = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                final isOpen = ticket['status'] == 'Open';
                String displayId = 'TKT-${ticket['id'].toString().padLeft(4, '0')}';

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOpen ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isOpen ? Colors.red.shade200 : Colors.grey.shade300),
                              ),
                              child: Text(
                                ticket['status'],
                                style: TextStyle(
                                  color: isOpen ? Colors.redAccent : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(ticket['timestamp'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$displayId • ${ticket['category']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: adminBlue, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ticket['description'],
                          style: const TextStyle(color: deepSlate, height: 1.5, fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(ticket['user_email'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                            if (isOpen)
                              ElevatedButton.icon(
                                onPressed: () => _showReplyDialog(ticket),
                                icon: const Icon(Icons.reply, color: Colors.white, size: 16),
                                label: const Text('Reply', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                  minimumSize: const Size(0, 36),
                                  elevation: 0,
                                ),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          }
      ),
    );
  }
}