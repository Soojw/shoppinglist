import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/database_service.dart';
import '../models/price_model.dart';
import 'product_page.dart';

class FullListPage extends StatefulWidget {
  final String title;
  const FullListPage({super.key, required this.title});

  @override
  State<FullListPage> createState() => _FullListPageState();
}

class _FullListPageState extends State<FullListPage> {
  List<PriceDropItem> allProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAggregatedData();
  }

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

  Future<void> _fetchAggregatedData() async {
    Map<String, PriceDropItem> grouped = {};

    try {
      final String url = 'https://gist.githubusercontent.com/Soojw/75bc56ef66c5827c0b4a8c05a831d4d6/raw/final_data.csv?v=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<String> rows = response.body.split('\n');

        for (int i = 1; i < rows.length; i++) {
          String row = rows[i].trim();
          if (row.isEmpty) continue;

          List<String> cols = _parseCsvRow(row);
          if (cols.length < 12) continue;

          String safeBarcode = cols.length >= 14 ? cols[13].trim() : 'N/A';
          double p = double.tryParse(cols[3].trim()) ?? 0.0;
          String priceStr = 'RM ${p.toStringAsFixed(2)}';
          String code = cols[2].trim();

          StorePrice sp = StorePrice(storeName: cols[8].trim(), price: priceStr, state: cols[11].trim(), date: cols[0].trim());

          if (grouped.containsKey(code)) {
            grouped[code]!.storePrices.add(sp);
            double currentMin = double.tryParse(grouped[code]!.newPrice.replaceAll('RM ', '')) ?? 0.0;
            if (p < currentMin) grouped[code]!.newPrice = priceStr;
          } else {
            grouped[code] = PriceDropItem(
              itemCode: code, barcode: safeBarcode, category: cols[7].trim(), title: cols[4].trim(),
              oldPrice: '', newPrice: priceStr, store: cols[8].trim(), details: 'Source: Data.gov.my',
              imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=800',
              isLocal: false, storePrices: [sp],
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading full list data: $e');
    }

    if (mounted) {
      setState(() {
        List<PriceDropItem> top15 = grouped.values.take(15).toList();
        for (var item in top15) {
          double p = double.tryParse(item.newPrice.replaceAll('RM ', '')) ?? 0.0;
          item.oldPrice = 'RM ${(p * 1.2).toStringAsFixed(2)}';
        }
        allProducts = top15;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color deepSlate = Color(0xFF1E293B);
    const Color primaryGreen = Color(0xFF059669);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, color: deepSlate)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: deepSlate)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : allProducts.isEmpty
          ? const Center(child: Text('No products available.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: allProducts.length,
        itemBuilder: (context, index) {
          final item = allProducts[index];
          return Card(
            elevation: 0, margin: const EdgeInsets.only(bottom: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(item: item))),
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
                              if (item.oldPrice.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(item.oldPrice, style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                              ],
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