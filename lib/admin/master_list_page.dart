import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/database_service.dart';
import '../models/price_model.dart';
import '../screens/product_page.dart';

class MasterListPage extends StatefulWidget {
  const MasterListPage({super.key});

  @override
  State<MasterListPage> createState() => _MasterListPageState();
}

class _MasterListPageState extends State<MasterListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<PriceDropItem> _catalogItems = [];
  List<PriceDropItem> _filteredItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    Map<String, PriceDropItem> grouped = {};

    try {
      final localItems = await DatabaseService().getFullCatalog();
      for (var item in localItems) {
        String code = item['item_code'] ?? 'LOCAL';
        String priceStr = item['price'] != null ? 'RM ${item['price']}' : 'N/A';
        StorePrice sp = StorePrice(storeName: 'Local Store', price: priceStr, state: 'Local DB', date: 'Now');

        if (grouped.containsKey(code)) {
          grouped[code]!.storePrices.add(sp);
        } else {
          grouped[code] = PriceDropItem(
            itemCode: code, barcode: item['barcode'] ?? 'N/A', category: item['category'] ?? 'UNKNOWN',
            title: item['item_name'] ?? 'Unknown', oldPrice: '', newPrice: priceStr, store: 'Local Store', details: 'Local DB',
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
              oldPrice: '',
              newPrice: priceStr, store: cols[8].trim(), details: 'Source: Data.gov.my',
              imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=800',
              isLocal: false, storePrices: [sp],
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading master catalog: $e');
    }

    if (mounted) {
      setState(() {
        _catalogItems = grouped.values.toList();
        _filteredItems = _catalogItems;
        _isLoading = false;
      });
    }
  }

  void _filterSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredItems = _catalogItems;
      });
      return;
    }

    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      _filteredItems = _catalogItems.where((item) {
        return item.title.toLowerCase().contains(lowerCaseQuery) || item.itemCode.toLowerCase().contains(lowerCaseQuery) || item.barcode.toLowerCase().contains(lowerCaseQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF059669);
    const Color deepSlate = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: const Text('Master Product List', style: TextStyle(fontWeight: FontWeight.bold, color: deepSlate)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: deepSlate)),
      body: Column(
        children: [
          Container(
            color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController, onChanged: _filterSearch,
              decoration: InputDecoration(
                hintText: 'Search by item name, SKU or Barcode...', hintStyle: const TextStyle(color: Colors.grey), prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); _filterSearch(''); }) : null,
                filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryGreen))
                : _filteredItems.isEmpty
                ? const Center(child: Text('No products found matching your search.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];

                return Card(
                  elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(item: item, isAdminView: true, isLocalItem: item.isLocal))).then((needsRefresh) {
                        if (needsRefresh == true) _loadCatalog();
                      });
                    },
                    leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: !item.isLocal ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)), child: Icon(!item.isLocal ? Icons.cloud_done : Icons.dns, color: !item.isLocal ? const Color(0xFF3B82F6) : primaryGreen)),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('SKU: ${item.itemCode} | Store variants: ${item.storePrices.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}