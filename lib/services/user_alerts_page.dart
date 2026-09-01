import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/database_service.dart';
import '../models/price_model.dart';
import '../screens/product_page.dart';

class UserAlertsPage extends StatefulWidget {
  final String userEmail;
  const UserAlertsPage({super.key, required this.userEmail});

  @override
  State<UserAlertsPage> createState() => _UserAlertsPageState();
}

class _UserAlertsPageState extends State<UserAlertsPage> {
  List<PriceDropItem> _favoriteItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
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

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);

    try {
      final favoriteIds = await DatabaseService().getUserFavoriteIds(widget.userEmail);

      if (favoriteIds.isEmpty) {
        if (mounted) setState(() { _favoriteItems = []; _isLoading = false; });
        return;
      }

      Map<String, PriceDropItem> grouped = {};

      final localItems = await DatabaseService().getFullCatalog();
      for (var item in localItems) {
        String code = item['item_code'] ?? 'LOCAL';
        String title = item['item_name'] ?? 'Unknown';


        if (!favoriteIds.contains(code) && !favoriteIds.contains(title)) continue;

        String priceStr = item['price'] != null ? 'RM ${item['price']}' : 'N/A';
        StorePrice sp = StorePrice(storeName: 'Local Store', price: priceStr, state: 'Local DB', date: 'Now');

        if (grouped.containsKey(code)) {
          grouped[code]!.storePrices.add(sp);
        } else {
          grouped[code] = PriceDropItem(
            itemCode: code, barcode: item['barcode'] ?? 'N/A', category: item['category'] ?? 'UNKNOWN',
            title: title, oldPrice: '', newPrice: priceStr, store: 'Local Store', details: 'Local DB',
            imageUrl: item['image_url'] ?? 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=800',
            isLocal: true, storePrices: [sp],
          );
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

          String code = cols[2].trim();
          String title = cols[4].trim();


          if (!favoriteIds.contains(code) && !favoriteIds.contains(title)) continue;

          String safeBarcode = cols.length >= 14 ? cols[13].trim() : 'N/A';
          double p = double.tryParse(cols[3].trim()) ?? 0.0;
          String priceStr = 'RM ${p.toStringAsFixed(2)}';

          StorePrice sp = StorePrice(storeName: cols[8].trim(), price: priceStr, state: cols[11].trim(), date: cols[0].trim());

          if (grouped.containsKey(code)) {
            grouped[code]!.storePrices.add(sp);
            double currentMin = double.tryParse(grouped[code]!.newPrice.replaceAll('RM ', '')) ?? 0.0;
            if (p < currentMin) grouped[code]!.newPrice = priceStr;
          } else {
            grouped[code] = PriceDropItem(
              itemCode: code, barcode: safeBarcode, category: cols[7].trim(), title: title,
              oldPrice: '', newPrice: priceStr, store: cols[8].trim(), details: 'Source: Data.gov.my',
              imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=800',
              isLocal: false, storePrices: [sp],
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _favoriteItems = grouped.values.toList();
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint('Error loading alerts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color deepSlate = Color(0xFF1E293B);
    const Color primaryGreen = Color(0xFF059669);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Your Alerts', style: TextStyle(fontWeight: FontWeight.bold, color: deepSlate)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: deepSlate),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : _favoriteItems.isEmpty
          ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No tracked items yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          )
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _favoriteItems.length,
        itemBuilder: (context, index) {
          final item = _favoriteItems[index];
          return Card(
            elevation: 0, margin: const EdgeInsets.only(bottom: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(item: item))).then((_) => _loadFavorites());
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: NetworkImage(item.imageUrl), fit: BoxFit.cover))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
                          const SizedBox(height: 4),
                          Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: deepSlate)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(item.newPrice, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryGreen)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                                child: const Text('Tracking', style: TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}