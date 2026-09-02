import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/price_model.dart';
import 'product_page.dart';
import 'full_list_page.dart';
import '../services/user_alerts_page.dart';
import '../services/database_service.dart';
import 'notification_page.dart';
import '../services/user_provider.dart';
import 'smart_shopping_list.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String userStateFilter = "";
  late Future<List<PriceDropItem>> _livePriceDataFuture;

  String _currentGlobalLocation = 'Current GPS Location';
  List<String> _availableLocations = ['Current GPS Location'];

  @override
  void initState() {
    super.initState();
    _livePriceDataFuture = Future.value([]);
    _loadLocationsAndData();
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

    if (mounted) {
      setState(() {
        _availableLocations = combined;
        _currentGlobalLocation = active;
      });
    }

    await _detectActiveStateFilter(active);
    if (mounted) {
      setState(() {
        _livePriceDataFuture = _fetchLivePriceData();
      });
    }
  }

  Future<void> _updateGlobalLocation(String newLocation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global_active_location', newLocation);

    setState(() => _currentGlobalLocation = newLocation);

    await _detectActiveStateFilter(newLocation);
    setState(() => _livePriceDataFuture = _fetchLivePriceData());
  }

  Future<void> _detectActiveStateFilter(String locationSetting) async {
    try {
      String upperActive = locationSetting.toUpperCase();
      if (upperActive.contains('KUALA LUMPUR') || upperActive.contains('KL') || upperActive.contains('WANGSA MAJU') || upperActive.contains('TARUMT')) {
        setState(() => userStateFilter = "Kuala Lumpur");
      } else if (upperActive.contains('SELANGOR') || upperActive.contains('PETALING') || upperActive.contains('SHAH ALAM') || upperActive.contains('KELANA JAYA')) {
        setState(() => userStateFilter = "Selangor");
      } else if (upperActive.contains('PENANG') || upperActive.contains('GEORGETOWN')) {
        setState(() => userStateFilter = "Pulau Pinang");
      } else if (locationSetting == 'Current GPS Location') {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return;
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) return;
        }

        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json');
        final response = await http.get(url, headers: {'User-Agent': 'SmartShoppingDemoApp'});
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final address = data['address'] ?? {};
          String state = address['state'] ?? address['city'] ?? 'Kuala Lumpur';
          if (mounted) setState(() => userStateFilter = state.replaceAll('W.P. ', '').replaceAll('Wilayah Persekutuan ', ''));
        }
      } else {
        setState(() => userStateFilter = "Kuala Lumpur");
      }
    } catch (e) {
      if (mounted) setState(() => userStateFilter = "Kuala Lumpur");
    }
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 18) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  String _getSmartImageUrl(String itemName) {
    String name = itemName.toLowerCase();

    if (name.contains('telur')) {
      return 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=800&q=80';
    }
    else if (name.contains('ayam')) {
      return 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=800&q=80';
    }
    else if (name.contains('ikan') || name.contains('sotong') || name.contains('udang')) {
      return 'https://images.unsplash.com/photo-1615141982883-c7ad0e69fd62?auto=format&fit=crop&w=800&q=80';
    }
    else if (name.contains('bawang')) {
      return 'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?auto=format&fit=crop&w=800&q=80';
    }
    else if (name.contains('cili')) {

      return 'https://images.pexels.com/photos/1435904/pexels-photo-1435904.jpeg?auto=compress&cs=tinysrgb&w=800';
    }
    else if (name.contains('kacang')) {
      return 'https://commons.wikimedia.org/wiki/Special:FilePath/Peanuts.jpg?width=800';
    }
    else if (name.contains('tomato')) {
      return 'https://commons.wikimedia.org/wiki/Special:FilePath/Tomatoes.jpg?width=800';
    }
    else if (name.contains('sayur') || name.contains('kobis')) {
      return 'https://commons.wikimedia.org/wiki/Special:FilePath/Vegetables.jpg?width=800';
    }
    else if (name.contains('minyak')) {
      return 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=800&q=80';
    }
    else if (name.contains('beras')) {
      return 'https://images.unsplash.com/photo-1586201375761-83865001e8ac?auto=format&fit=crop&w=800&q=80';
    }
    else if (name.contains('100 plus') || name.contains('100plus') || name.contains('100-plus')) {
      return 'https://images.unsplash.com/photo-1523362628745-0c100150b504?auto=format&fit=crop&w=800&q=80';
    }
    else if (name.contains('milo') || name.contains('nescafe') || name.contains('teh') || name.contains('kopi') || name.contains('minuman') || name.contains('air')) {
      return 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=800&q=80';
    }

    return 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=800&q=80';
  }

  List<String> _parseCsvRow(String row) {
    List<String> cols = []; StringBuffer currentCol = StringBuffer(); bool insideQuotes = false;
    for (int i = 0; i < row.length; i++) {
      if (row[i] == '"') insideQuotes = !insideQuotes;
      else if (row[i] == ',' && !insideQuotes) { cols.add(currentCol.toString().trim()); currentCol.clear(); }
      else currentCol.write(row[i]);
    }
    cols.add(currentCol.toString().trim()); return cols;
  }

  Future<List<PriceDropItem>> _fetchLivePriceData() async {
    Map<String, PriceDropItem> grouped = {};
    final String csvUrl = 'https://gist.githubusercontent.com/Soojw/75bc56ef66c5827c0b4a8c05a831d4d6/raw/final_data.csv?v=${DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await http.get(Uri.parse(csvUrl));
      if (response.statusCode == 200) {
        List<String> rows = response.body.split('\n');
        for (int i = 1; i < rows.length; i++) {
          String row = rows[i].trim();
          if (row.isEmpty) continue;

          List<String> cols = _parseCsvRow(row);
          if (cols.length < 12) continue;

          String storeState = cols[11].trim().toLowerCase();
          if (userStateFilter.isNotEmpty) {
            String target = userStateFilter.toLowerCase();
            bool matches = false;
            if (target == 'kuala lumpur' && (storeState.contains('kuala lumpur') || storeState.contains('wilayah persekutuan') || storeState.contains('w.p.'))) {
              matches = true;
            } else if (storeState.contains(target) || target.contains(storeState)) {
              matches = true;
            }
            if (!matches) continue;
          }

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
              imageUrl: _getSmartImageUrl(cols[4].trim()),
              isLocal: false, storePrices: [sp],
            );
          }
        }
        List<PriceDropItem> top15 = grouped.values.take(15).toList();
        for (var item in top15) { double p = double.tryParse(item.newPrice.replaceAll('RM ', '')) ?? 0.0; item.oldPrice = 'RM ${(p * 1.2).toStringAsFixed(2)}'; }
        return top15;
      }
    } catch (e) { debugPrint('Error: $e'); }
    return [];
  }

  Future<List<PriceDropItem>> _fetchUserFavoritePreviews(String email) async {
    if (email.isEmpty) return [];
    final favoriteIds = await DatabaseService().getUserFavoriteIds(email);
    if (favoriteIds.isEmpty) return [];

    Map<String, PriceDropItem> grouped = {};
    try {
      final localItems = await DatabaseService().getFullCatalog();
      for (var item in localItems) {
        String code = item['item_code'] ?? 'LOCAL'; String title = item['item_name'] ?? 'Unknown';
        if (!favoriteIds.contains(code) && !favoriteIds.contains(title)) continue;
        grouped[code] = PriceDropItem(
          itemCode: code, barcode: item['barcode'] ?? 'N/A', category: item['category'] ?? 'UNKNOWN',
          title: title, oldPrice: '', newPrice: item['price'] != null ? 'RM ${item['price']}' : 'N/A', store: 'Local Store', details: 'Local DB',
          imageUrl: item['image_url'] ?? 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=800', isLocal: true,
        );
      }
      final response = await http.get(Uri.parse('https://gist.githubusercontent.com/Soojw/75bc56ef66c5827c0b4a8c05a831d4d6/raw/final_data.csv?v=${DateTime.now().millisecondsSinceEpoch}'));
      if (response.statusCode == 200) {
        List<String> rows = response.body.split('\n');
        for (int i = 1; i < rows.length; i++) {
          String row = rows[i].trim(); if (row.isEmpty) continue;
          List<String> cols = _parseCsvRow(row); if (cols.length < 12) continue;

          String storeState = cols[11].trim().toLowerCase();
          if (userStateFilter.isNotEmpty) {
            String target = userStateFilter.toLowerCase();
            bool matches = false;
            if (target == 'kuala lumpur' && (storeState.contains('kuala lumpur') || storeState.contains('wilayah persekutuan') || storeState.contains('w.p.'))) {
              matches = true;
            } else if (storeState.contains(target) || target.contains(storeState)) {
              matches = true;
            }
            if (!matches) continue;
          }

          String code = cols[2].trim(); String title = cols[4].trim();
          if (!favoriteIds.contains(code) && !favoriteIds.contains(title)) continue;

          double p = double.tryParse(cols[3].trim()) ?? 0.0; String priceStr = 'RM ${p.toStringAsFixed(2)}';
          if (grouped.containsKey(code)) {
            if (p < (double.tryParse(grouped[code]!.newPrice.replaceAll('RM ', '')) ?? 0.0)) grouped[code]!.newPrice = priceStr;
          } else {
            grouped[code] = PriceDropItem(
              itemCode: code, barcode: cols.length >= 14 ? cols[13].trim() : 'N/A', category: cols[7].trim(), title: title,
              oldPrice: '', newPrice: priceStr, store: cols[8].trim(), details: 'Data.gov.my',
              imageUrl: _getSmartImageUrl(title),
              isLocal: false,
            );
          }
        }
      }
    } catch (e) { debugPrint('Error: $e'); }
    return grouped.values.take(2).toList();
  }

  void _showDemoToast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFF059669), duration: const Duration(seconds: 1)));

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF059669);
    const Color lightGreenBg = Color(0xFFECFDF5);
    const Color deepSlate = Color(0xFF1E293B);

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final String currentUserName = userProvider.isLoggedIn ? (userProvider.userName.isNotEmpty ? userProvider.userName.toUpperCase() : "USER") : "GUEST";

        return Scaffold(
          backgroundColor: lightGreenBg,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadLocationsAndData,
              color: primaryGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(top: 40.0, left: 20.0, right: 20.0, bottom: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${getGreeting()},\n$currentUserName', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: deepSlate, height: 1.2)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: primaryGreen),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _currentGlobalLocation,
                                          isExpanded: true,
                                          isDense: true,
                                          icon: const Icon(Icons.keyboard_arrow_down, color: primaryGreen, size: 18),
                                          items: _availableLocations.map((String loc) {
                                            String displayName = loc;
                                            if (loc.contains('(')) displayName = loc.split(' (').first;
                                            return DropdownMenuItem<String>(
                                              value: loc,
                                              child: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: primaryGreen, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            );
                                          }).toList(),
                                          onChanged: (String? newVal) {
                                            if (newVal != null) _updateGlobalLocation(newVal);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              if (!userProvider.isLoggedIn) { _showDemoToast('Please Log In to view notifications'); return; }
                              Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationPage(userEmail: userProvider.userEmail))).then((_) { if (mounted) setState(() {}); });
                            },
                            child: FutureBuilder<int>(
                              future: userProvider.isLoggedIn ? DatabaseService().getUnreadNotificationCount(userProvider.userEmail) : Future.value(0),
                              builder: (context, snapshot) {
                                int count = snapshot.data ?? 0;
                                return Container(
                                  padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Icon(Icons.notifications_none, color: deepSlate, size: 28),
                                      if (count > 0)
                                        Positioned(right: -4, top: -4, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Row(children: [Text('Item Price Drop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: deepSlate)), SizedBox(width: 8), Icon(Icons.sensors, color: Colors.redAccent, size: 16)]), TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FullListPage(title: 'Item Price Drop'))), child: const Text('See all', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)))]),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 200,
                        child: FutureBuilder<List<PriceDropItem>>(
                          future: _livePriceDataFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryGreen));
                            else if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No matching price drops in this area.', style: TextStyle(color: Colors.grey)));
                            else {
                              final items = snapshot.data!;
                              return ListView.builder(
                                scrollDirection: Axis.horizontal, itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 16.0),
                                    child: InkWell(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(item: item))).then((_) => setState(() {})),
                                      borderRadius: BorderRadius.circular(20),
                                      child: _buildPriceDropCard(category: item.category, title: item.title, oldPrice: item.oldPrice, newPrice: item.newPrice, store: item.store, iconData: Icons.shopping_basket_outlined),
                                    ),
                                  );
                                },
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text('Basket Optimizer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: deepSlate)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), leading: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle), child: const Icon(Icons.receipt_long, color: primaryGreen)),
                          title: const Text('Smart Shopping List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), subtitle: const Text('Calculate lowest total bill for your basket', style: TextStyle(color: Colors.grey, fontSize: 12)), trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SmartShoppingPage())),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Your alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: deepSlate)), TextButton(onPressed: () { if (!userProvider.isLoggedIn) { _showDemoToast('Please Log In first'); return; } Navigator.push(context, MaterialPageRoute(builder: (context) => UserAlertsPage(userEmail: userProvider.userEmail))); }, child: const Text('View all', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)))]),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: !userProvider.isLoggedIn ? const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Center(child: Text('Sign in to view your personalized alerts.', style: TextStyle(color: Colors.grey)))) : FutureBuilder<List<PriceDropItem>>(
                          future: _fetchUserFavoritePreviews(userProvider.userEmail),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Center(child: CircularProgressIndicator(color: primaryGreen)));
                            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Center(child: Text('No favorites yet. Tap ❤️ on items to track!', style: TextStyle(color: Colors.grey))));
                            final items = snapshot.data!;
                            return Column(
                              children: items.asMap().entries.map((entry) {
                                int idx = entry.key; var item = entry.value;
                                Widget row = _buildAlertRow(icon: Icons.favorite_border, iconBgColor: const Color(0xFFD1FAE5), iconColor: primaryGreen, title: 'Tracked Item Live Price', subtitle: '${item.title} - Now ${item.newPrice}', time: 'Live', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(item: item))).then((_) => setState(() {})));
                                if (idx < items.length - 1) return Column(children: [row, const Divider(height: 32, color: Color(0xFFF1F5F9))]); return row;
                              }).toList(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriceDropCard({required String category, required String title, required String oldPrice, required String newPrice, required String store, required IconData iconData}) {
    return Container(
      width: 240, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)), Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle), child: Icon(iconData, color: const Color(0xFF059669), size: 20))]),
          const SizedBox(height: 8),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)), child: const Text('↘ Live Price', style: TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(oldPrice, style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)), const SizedBox(width: 8), Text(newPrice, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF059669)))]),
        ],
      ),
    );
  }

  Widget _buildAlertRow({required IconData icon, required Color iconBgColor, required Color iconColor, required String title, required String subtitle, required String time, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () => _showDemoToast('Opening Alert Details...'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)])),
          const SizedBox(width: 8), Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}