import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_model.dart';
import '../services/database_service.dart';
import 'full_list_page.dart';
import 'product_page.dart';
import '../models/price_model.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<PriceDropItem> allProducts = [];
  bool isLoading = true;
  String userStateFilter = "";

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  List<String> _recentSearches = [];

  String _currentGlobalLocation = 'Current GPS Location';
  List<String> _availableLocations = ['Current GPS Location'];

  @override
  void initState() {
    super.initState();
    _initializeSearch();
  }

  String _getSmartImageUrl(String itemName) {
    String name = itemName.toLowerCase();
    if (name.contains('ayam')) {
      return 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=800&q=80';
    } else if (name.contains('ikan') || name.contains('sotong') || name.contains('udang')) {
      return 'https://images.unsplash.com/photo-1615141982883-c7ad0e69fd62?auto=format&fit=crop&w=800&q=80';
    } else if (name.contains('cili') || name.contains('sayur') || name.contains('kobis') || name.contains('tomato')) {
      return 'https://images.unsplash.com/photo-1596162954151-cdcb927f8b72?auto=format&fit=crop&w=800&q=80';
    } else if (name.contains('telur')) {
      return 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=800&q=80';
    } else if (name.contains('minyak')) {
      return 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=800&q=80';
    } else if (name.contains('susu')) {
      return 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=800&q=80';
    } else if (name.contains('beras')) {
      return 'https://images.unsplash.com/photo-1586201375761-83865001e8ac?auto=format&fit=crop&w=800&q=80';
    } else if (name.contains('milo') || name.contains('nescafe') || name.contains('teh') || name.contains('kopi') || name.contains('minuman') || name.contains('air')) {
      return 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=800&q=80';
    }
    return 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=800&q=80';
  }

  Future<void> _initializeSearch() async {
    await _loadLocationsAndData();
  }

  Future<void> _loadLocationsAndData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList('saved_places_list') ?? [];
    String active = prefs.getString('global_active_location') ?? 'Current GPS Location';

    List<String> combined = ['Current GPS Location'];
    for (var s in saved) {
      if (s != 'Current GPS Location' && s.isNotEmpty) combined.add(s);
    }

    if (!combined.contains(active)) active = 'Current GPS Location';

    setState(() {
      _availableLocations = combined;
      _currentGlobalLocation = active;
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });

    await _detectActiveStateFilter(active);
    await _loadAllProducts();
  }

  Future<void> _updateGlobalLocation(String newLocation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global_active_location', newLocation);

    setState(() {
      _currentGlobalLocation = newLocation;
      isLoading = true;
    });

    await _detectActiveStateFilter(newLocation);
    await _loadAllProducts();
  }

  Future<void> _detectActiveStateFilter(String locationSetting) async {
    try {
      if (locationSetting == 'Current GPS Location') {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return;
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) return;
        }

        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (position.latitude < 0.0 || position.latitude > 10.0 || position.longitude < 98.0 || position.longitude > 120.0) {
          throw Exception('Outside Malaysia');
        }

        final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json');
        final response = await http.get(url, headers: {'User-Agent': 'SmartShoppingDemoApp'});
        if (response.statusCode == 200) _applyStateFromJson(response.body);

      } else {
        String addressToSearch = locationSetting;
        if (addressToSearch.contains('(')) {
          addressToSearch = addressToSearch.substring(addressToSearch.indexOf('(') + 1, addressToSearch.lastIndexOf(')'));
        }
        final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent('$addressToSearch, Malaysia')}&format=json&addressdetails=1&limit=1');
        final response = await http.get(url, headers: {'User-Agent': 'SmartShoppingDemoApp'});

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data.isNotEmpty) {
            final address = data[0]['address'] ?? {};
            String state = address['state'] ?? address['city'] ?? 'Kuala Lumpur';
            if (mounted) setState(() => userStateFilter = state.replaceAll('W.P. ', '').replaceAll('Wilayah Persekutuan ', ''));
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("State filter fallback to KL: $e");
      if (mounted) setState(() => userStateFilter = "Kuala Lumpur");
    }
  }

  void _applyStateFromJson(String jsonStr) {
    final data = json.decode(jsonStr);
    final address = data['address'] ?? {};
    String state = address['state'] ?? address['city'] ?? 'Kuala Lumpur';
    if (mounted) {
      setState(() {
        userStateFilter = state.replaceAll('W.P. ', '').replaceAll('Wilayah Persekutuan ', '');
      });
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> recents = prefs.getStringList('recent_searches') ?? [];
    recents.remove(query.trim());
    recents.insert(0, query.trim());
    if (recents.length > 5) recents = recents.sublist(0, 5);
    await prefs.setStringList('recent_searches', recents);
    if (mounted) setState(() => _recentSearches = recents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (errorNotification) {
          if (mounted) setState(() => _isListening = false);
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          localeId: 'ms_MY',
          onResult: (result) {
            setState(() {
              _searchController.text = result.recognizedWords;
              searchQuery = result.recognizedWords;
            });
            if (result.finalResult) _saveRecentSearch(result.recognizedWords);
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  Future<void> _scanBarcode() async {
    try {
      var result = await BarcodeScanner.scan();
      String barcodeScanRes = result.rawContent;
      if (barcodeScanRes.isNotEmpty && barcodeScanRes != '-1' && mounted) {
        setState(() {
          _searchController.text = barcodeScanRes;
          searchQuery = barcodeScanRes;
        });
        _saveRecentSearch(barcodeScanRes);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanned: $barcodeScanRes'), backgroundColor: const Color(0xFF059669), duration: const Duration(seconds: 2)));
      }
    } catch (e) { debugPrint("Barcode scan error: $e"); }
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

  Future<void> _loadAllProducts() async {
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
          String fallbackName = item['item_name'] ?? 'Unknown';
          grouped[code] = PriceDropItem(
            itemCode: code, barcode: item['barcode'] ?? 'N/A', category: item['category'] ?? 'UNKNOWN',
            title: fallbackName, oldPrice: '', newPrice: priceStr, store: 'Local Store', details: 'Local DB',
            imageUrl: (item['image_url'] != null && item['image_url'].toString().isNotEmpty) ? item['image_url'] : _getSmartImageUrl(fallbackName),
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

          String storeState = cols[11].trim().toLowerCase();
          if (userStateFilter.isNotEmpty) {
            if (!storeState.contains(userStateFilter.toLowerCase()) && !userStateFilter.toLowerCase().contains(storeState)) continue;
          }

          String safeBarcode = cols.length >= 14 ? cols[13].trim() : 'N/A';
          double p = double.tryParse(cols[3].trim()) ?? 0.0;
          String priceStr = 'RM ${p.toStringAsFixed(2)}';
          String code = cols[2].trim();
          String itemName = cols[4].trim();

          StorePrice sp = StorePrice(storeName: cols[8].trim(), price: priceStr, state: cols[11].trim(), date: cols[0].trim());

          if (grouped.containsKey(code)) {
            grouped[code]!.storePrices.add(sp);
            double currentMin = double.tryParse(grouped[code]!.newPrice.replaceAll('RM ', '')) ?? 0.0;
            if (p < currentMin) grouped[code]!.newPrice = priceStr;
          } else {
            grouped[code] = PriceDropItem(
              itemCode: code, barcode: safeBarcode, category: cols[7].trim(), title: itemName,
              oldPrice: '', newPrice: priceStr, store: cols[8].trim(), details: 'Source: Data.gov.my',
              imageUrl: _getSmartImageUrl(itemName),
              isLocal: false, storePrices: [sp],
            );
          }
        }
      }
    } catch (e) { debugPrint('Error loading search data: $e'); }

    if (mounted) setState(() { allProducts = grouped.values.toList(); isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    const Color deepSlate = Color(0xFF1E293B);
    const Color primaryGreen = Color(0xFF059669);

    final filteredProducts = allProducts.where((item) {
      return item.title.toLowerCase().contains(searchQuery.toLowerCase()) || item.barcode.contains(searchQuery);
    }).take(10).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: primaryGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currentGlobalLocation,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                            items: _availableLocations.map((String loc) {
                              String displayName = loc;
                              if (loc.contains('(')) displayName = loc.split(' (').first;
                              return DropdownMenuItem<String>(
                                value: loc,
                                child: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700, color: deepSlate, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (String? newVal) {
                              if (newVal != null) _updateGlobalLocation(newVal);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => searchQuery = value),
                    onSubmitted: (value) => _saveRecentSearch(value),
                    decoration: InputDecoration(
                      hintText: userStateFilter.isEmpty ? 'Search...' : 'Search near $userStateFilter...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (searchQuery.isNotEmpty) IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () => setState(() { _searchController.clear(); searchQuery = ''; })),
                          IconButton(icon: const Icon(Icons.qr_code_scanner, color: deepSlate), onPressed: _scanBarcode),
                          IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.redAccent : deepSlate), onPressed: _toggleListening),
                          const SizedBox(width: 8),
                        ],
                      ), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),

                if (_recentSearches.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Searches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: deepSlate)),
                      GestureDetector(
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('recent_searches');
                          setState(() { _recentSearches.clear(); });
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                      spacing: 10.0,
                      runSpacing: 10.0,
                      children: _recentSearches.map((query) => _buildRecentSearchChip(query)).toList()
                  ),
                ],

                const SizedBox(height: 40),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Search Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: deepSlate)), TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FullListPage(title: 'All Item Price Drops'))), child: const Text('View All >', style: TextStyle(color: Colors.grey)))]),
                const SizedBox(height: 10),
                if (isLoading) const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: primaryGreen)))
                else if (filteredProducts.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No matching products found in this area.', style: TextStyle(color: Colors.grey))))
                else
                  GridView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 16, mainAxisSpacing: 16),
                    itemCount: filteredProducts.length, itemBuilder: (context, index) => _buildProductCard(context, filteredProducts[index]),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearchChip(String label) {
    return InkWell(
      onTap: () {
        setState(() { _searchController.text = label; searchQuery = label; });
        _saveRecentSearch(label);
      },
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300, width: 0.5)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w500)),
            ],
          )
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, PriceDropItem item) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(item: item))),
      child: Container(
        padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(height: 80, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: NetworkImage(item.imageUrl), fit: BoxFit.cover)))),
            const Spacer(),
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text(item.category, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity, height: 32,
              child: ElevatedButton(
                onPressed: () async {
                  await DatabaseService().insertItem(CartItemModel(itemName: item.title, price: item.newPrice, storeName: item.storePrices.isNotEmpty ? item.storePrices.first.storeName : item.store, quantity: 1));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.title} added to list!'), backgroundColor: const Color(0xFF059669), duration: const Duration(seconds: 1)));
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                child: const Text('Add to List', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}