import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/database_service.dart';

class AdminTrendAnalyticsPage extends StatefulWidget {
  const AdminTrendAnalyticsPage({super.key});

  @override
  State<AdminTrendAnalyticsPage> createState() => _AdminTrendAnalyticsPageState();
}

class _AdminTrendAnalyticsPageState extends State<AdminTrendAnalyticsPage> {
  bool _isLoading = true;
  List<MapEntry<String, int>> _macroTrends = [];
  List<Map<String, dynamic>> _microItems = [];
  int _totalFavorites = 0;

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  List<String> _parseCsvRow(String row) {
    List<String> cols = [];
    StringBuffer currentCol = StringBuffer();
    bool insideQuotes = false;
    for (int i = 0; i < row.length; i++) {
      if (row[i] == '"') insideQuotes = !insideQuotes;
      else if (row[i] == ',' && !insideQuotes) { cols.add(currentCol.toString().trim()); currentCol.clear(); }
      else currentCol.write(row[i]);
    }
    cols.add(currentCol.toString().trim()); return cols;
  }

  Future<void> _fetchAnalyticsData() async {
    try {
      final topItems = await DatabaseService().getTopFavoritedItems();
      if (topItems.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      Map<String, String> productToCategory = {};

      final localItems = await DatabaseService().getFullCatalog();
      for (var item in localItems) {
        if (item['item_name'] != null) {
          productToCategory[item['item_name'].toString().trim().toLowerCase()] = item['category']?.toString().toUpperCase() ?? 'OTHER';
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
          if (cols.length > 7) {
            String itemName = cols[4].trim().toLowerCase();
            String category = cols[7].trim().toUpperCase();
            productToCategory[itemName] = category;
          }
        }
      }

      Map<String, int> categoryCounts = {};
      int total = 0;

      for (var row in topItems) {
        String rawName = row['product_name'];
        String lookupName = rawName.trim().toLowerCase();
        int count = row['count'];
        total += count;

        String cat = productToCategory[lookupName] ?? 'GENERAL / OTHERS';
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + count;
      }

      var sortedCats = categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _macroTrends = sortedCats;
        _microItems = topItems;
        _totalFavorites = total;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Analytics Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color adminBlue = Color(0xFF2563EB);
    const Color deepSlate = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Trend Analytics', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: adminBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: adminBlue))
          : _totalFavorites == 0
          ? const Center(child: Text("No user favorites data yet.", style: TextStyle(color: Colors.grey)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb, color: Color(0xFF3B82F6)),
                  SizedBox(width: 12),
                  Expanded(child: Text('Action: Leverage the dominant category demand below to negotiate bulk promotions with suppliers.', style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 13, height: 1.4))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('📊 MACRO TRENDS (By Category)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _macroTrends.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final cat = _macroTrends[index];
                  final double percentage = (cat.value / _totalFavorites);
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(cat.key, style: const TextStyle(fontWeight: FontWeight.bold, color: deepSlate)),
                            Text('${(percentage * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFF59E0B))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: const Color(0xFFFEF3C7),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 6,
                        ),
                        const SizedBox(height: 8),
                        Text('${cat.value} items saved in this category', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            const Text('🔥 MICRO HOT ITEMS (Top Items)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _microItems.length > 5 ? 5 : _microItems.length,
              itemBuilder: (context, index) {
                final item = _microItems[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFEF2F2),
                      child: Text('#${index + 1}', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                    ),
                    title: Text(item['product_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: deepSlate)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: Text('${item['count']} Saves', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}