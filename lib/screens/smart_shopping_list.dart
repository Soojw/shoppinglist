import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../services/database_service.dart';
import '../models/cart_model.dart';

class SmartShoppingPage extends StatefulWidget {
  const SmartShoppingPage({super.key});

  @override
  State<SmartShoppingPage> createState() => _SmartShoppingPageState();
}

class _SmartShoppingPageState extends State<SmartShoppingPage> {
  late Future<List<CartItemModel>> _cartItemsFuture;
  static final Map<String, LatLng> _geoCache = {};

  @override
  void initState() {
    super.initState();
    _refreshCart();
  }

  void _refreshCart() {
    setState(() {
      _cartItemsFuture = DatabaseService().getCartItems();
    });
  }

  Future<LatLng?> _geocodeAddress(String storeName, String searchAddr) async {
    final Map<String, LatLng> demoStoreLocations = {
      'GIANT SUPERMARKET KELANA JAYA': const LatLng(3.1044, 101.5960),
      'TESCO EXTRA ARA DAMANSARA': const LatLng(3.1116, 101.5743),
      'TESCO SEKSYEN 13': const LatLng(3.0747, 101.5285),
      'LOTUS\'S CHERAS': const LatLng(3.1024, 101.7328),
      'AEON ( METRO PRIMA )': const LatLng(3.2145, 101.6391),
      'AEON BIG ( KEPONG )': const LatLng(3.2154, 101.6444),
      'NSK TRADE CITY ( KEPONG )': const LatLng(3.2030, 101.6662),
      'SEGI FRESH ( TAMAN SHAMELIN )': const LatLng(3.1253, 101.7343),
      'AEON ( WANGSA MAJU )': const LatLng(3.2035, 101.7316),
      'AEON (TAMAN MALURI )': const LatLng(3.1278, 101.7288),
      'THE STORE ( PUDU PLAZA )': const LatLng(3.1367, 101.7124),
      'PASAR AWAM TAIPING': const LatLng(4.8517, 100.7431),
    };

    for (var key in demoStoreLocations.keys) {
      if (storeName.toUpperCase().contains(key) || key.contains(storeName.toUpperCase())) {
        return demoStoreLocations[key];
      }
    }

    if (_geoCache.containsKey(searchAddr)) return _geoCache[searchAddr];
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent('$searchAddr, Malaysia')}&format=json&limit=1&countrycodes=my');
      final response = await http.get(url, headers: {'User-Agent': 'SmartShoppingOptimizer/1.0'});
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final pos = LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
          _geoCache[searchAddr] = pos;
          return pos;
        }
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
    return null;
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

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF059669);
    const Color deepSlate = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Smart Shopping List', style: TextStyle(color: deepSlate, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: deepSlate),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [

          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              children: [
                Text('BASKET OPTIMIZER', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                SizedBox(height: 8),
                Text('Save on the whole shop.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: deepSlate)),
                SizedBox(height: 8),
                Text('Your entire list calculated across competing retailers to find the absolute lowest total bill.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CartItemModel>>(
              future: _cartItemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryGreen));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Your basket is empty\nGo to search to add items', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));

                final items = snapshot.data!;
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle), child: const Icon(Icons.shopping_basket, color: primaryGreen)),
                        title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: deepSlate)),
                        subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(item.price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: primaryGreen))),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey), onPressed: () async { await DatabaseService().updateItemQuantity(item.id, item.quantity - 1); _refreshCart(); }),
                            SizedBox(width: 24, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: deepSlate))),
                            IconButton(icon: const Icon(Icons.add_circle_outline, color: primaryGreen), onPressed: () async { await DatabaseService().updateItemQuantity(item.id, item.quantity + 1); _refreshCart(); }),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analyzing Dual Locations... ⏳'), backgroundColor: primaryGreen, duration: Duration(milliseconds: 1000)));

                    final items = await DatabaseService().getCartItems();
                    if (items.isEmpty) return;

                    double baseTotalPrice = 0.0;
                    for (var item in items) {
                      double price = double.tryParse(item.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
                      baseTotalPrice += (price * item.quantity);
                    }

                    final prefs = await SharedPreferences.getInstance();
                    double searchRadius = prefs.getDouble('search_radius') ?? 15.0;



                    LatLng gpsPos = const LatLng(3.140853, 101.693207);
                    try {
                      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                      if (!(position.latitude > 10.0 || position.latitude < 0.0 || position.longitude < 98.0 || position.longitude > 120.0)) {
                        gpsPos = LatLng(position.latitude, position.longitude);
                      }
                    } catch (e) { debugPrint("GPS error: $e"); }


                    LatLng? customPos;
                    String customPlaceName = '';
                    List<String> savedPlaces = prefs.getStringList('saved_places_list') ?? [];

                    for (String place in savedPlaces) {
                      if (place != 'Current GPS Location') {
                        customPlaceName = place;
                        String addressToGeocode = place;
                        if (place.contains('(')) {

                          addressToGeocode = place.substring(place.indexOf('(') + 1, place.lastIndexOf(')'));
                        }
                        customPos = await _geocodeAddress('START_POINT', addressToGeocode);
                        break;
                      }
                    }

                    final Distance distanceCalc = const Distance();
                    int priceColIndex = 3, itemNameColIndex = 4, storeNameColIndex = 8, addressColIndex = 9, stateColIndex = 11;


                    Map<String, double> storeBillsGps = {};
                    Map<String, dynamic> storeDetailsGps = {};
                    Map<String, double> storeBillsCustom = {};
                    Map<String, dynamic> storeDetailsCustom = {};

                    try {
                      final String csvUrl = 'https://gist.githubusercontent.com/Soojw/75bc56ef66c5827c0b4a8c05a831d4d6/raw/final_data.csv?v=${DateTime.now().millisecondsSinceEpoch}';
                      final response = await http.get(Uri.parse(csvUrl));

                      if (response.statusCode == 200) {
                        List<String> rows = response.body.split('\n');
                        Map<String, LatLng?> validStoreCache = {};

                        for (int i = 1; i < rows.length; i++) {
                          String row = rows[i].trim();
                          if (row.isEmpty) continue;
                          List<String> cols = _parseCsvRow(row);
                          if (cols.length <= stateColIndex) continue;

                          String storeName = cols[storeNameColIndex].trim();
                          String itemName = cols[itemNameColIndex].trim();
                          double realPrice = double.tryParse(cols[priceColIndex].trim()) ?? 0.0;

                          int cartQuantity = 0;
                          for (var cartItem in items) {
                            if (cartItem.itemName.toLowerCase().trim() == itemName.toLowerCase().trim()) {
                              cartQuantity = cartItem.quantity;
                              break;
                            }
                          }
                          if (cartQuantity == 0) continue;

                          if (!validStoreCache.containsKey(storeName)) {
                            String searchAddr = '$storeName ${cols[addressColIndex].trim()} ${cols[stateColIndex].trim()}'.trim();
                            validStoreCache[storeName] = await _geocodeAddress(storeName, searchAddr);
                          }

                          LatLng? pos = validStoreCache[storeName];
                          if (pos != null) {
                            String searchAddr = '$storeName ${cols[addressColIndex].trim()} ${cols[stateColIndex].trim()}'.trim();


                            double kmGps = distanceCalc.as(LengthUnit.Kilometer, gpsPos, pos);
                            if (kmGps <= searchRadius) {
                              storeBillsGps[storeName] = (storeBillsGps[storeName] ?? 0.0) + (realPrice * cartQuantity);
                              storeDetailsGps[storeName] = {'address': searchAddr, 'position': pos, 'distance': kmGps};
                            }


                            if (customPos != null) {
                              double kmCustom = distanceCalc.as(LengthUnit.Kilometer, customPos, pos);
                              if (kmCustom <= searchRadius) {
                                storeBillsCustom[storeName] = (storeBillsCustom[storeName] ?? 0.0) + (realPrice * cartQuantity);
                                storeDetailsCustom[storeName] = {'address': searchAddr, 'position': pos, 'distance': kmCustom};
                              }
                            }
                          }
                        }
                      }
                    } catch (e) { debugPrint("CSV error: $e"); }


                    String bestStoreGps = 'No exact matches in ${searchRadius.toInt()}km';
                    double bestPriceGps = baseTotalPrice;
                    LatLng? bestPosGps;
                    String bestAddrGps = '';
                    if (storeBillsGps.isNotEmpty) {
                      var sorted = storeBillsGps.entries.toList()..sort((a, b) {
                        int pCmp = a.value.compareTo(b.value);
                        if (pCmp != 0) return pCmp;
                        return (storeDetailsGps[a.key]?['distance'] ?? double.infinity).compareTo(storeDetailsGps[b.key]?['distance'] ?? double.infinity);
                      });
                      bestStoreGps = sorted.first.key;
                      bestPriceGps = sorted.first.value;
                      bestPosGps = storeDetailsGps[bestStoreGps]['position'];
                      bestAddrGps = storeDetailsGps[bestStoreGps]['address'];
                    }
                    double savedGps = (baseTotalPrice - bestPriceGps) > 0 ? (baseTotalPrice - bestPriceGps) : 0.0;


                    String bestStoreCustom = 'No exact matches in ${searchRadius.toInt()}km';
                    double bestPriceCustom = baseTotalPrice;
                    LatLng? bestPosCustom;
                    String bestAddrCustom = '';
                    if (customPos != null && storeBillsCustom.isNotEmpty) {
                      var sorted = storeBillsCustom.entries.toList()..sort((a, b) {
                        int pCmp = a.value.compareTo(b.value);
                        if (pCmp != 0) return pCmp;
                        return (storeDetailsCustom[a.key]?['distance'] ?? double.infinity).compareTo(storeDetailsCustom[b.key]?['distance'] ?? double.infinity);
                      });
                      bestStoreCustom = sorted.first.key;
                      bestPriceCustom = sorted.first.value;
                      bestPosCustom = storeDetailsCustom[bestStoreCustom]['position'];
                      bestAddrCustom = storeDetailsCustom[bestStoreCustom]['address'];
                    }
                    double savedCustom = (baseTotalPrice - bestPriceCustom) > 0 ? (baseTotalPrice - bestPriceCustom) : 0.0;

                    if (context.mounted) {
                      showModalBottomSheet(
                          context: context, backgroundColor: Colors.white, isScrollControlled: true,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                          builder: (context) {
                            return Padding(
                              padding: EdgeInsets.only(
                                  left: 24, right: 24, top: 24,
                                  bottom: MediaQuery.of(context).padding.bottom + 24
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, color: primaryGreen, size: 64),
                                  const SizedBox(height: 16),
                                  const Text('Optimization Complete! ✨', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: deepSlate)),
                                  const SizedBox(height: 8),
                                  Text('Compared real prices within your ${searchRadius.toInt()}km radius.', style: const TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 24),


                                  _buildResultCard(
                                      context: context, title: '📍 Based on Current GPS',
                                      storeName: bestStoreGps, price: bestPriceGps, savedAmt: savedGps,
                                      pos: bestPosGps, address: bestAddrGps, originPos: gpsPos
                                  ),


                                  if (customPos != null) ...[
                                    const SizedBox(height: 16),
                                    _buildResultCard(
                                        context: context, title: '🏠 Based on Saved Place:\n$customPlaceName',
                                        storeName: bestStoreCustom, price: bestPriceCustom, savedAmt: savedCustom,
                                        pos: bestPosCustom, address: bestAddrCustom, originPos: customPos
                                    ),
                                  ]
                                ],
                              ),
                            );
                          }
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: const Text('Calculate lowest basket price ✨', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required BuildContext context, required String title, required String storeName,
    required double price, required double savedAmt, required LatLng? pos,
    required String address, required LatLng originPos
  }) {
    const Color primaryGreen = Color(0xFF059669);
    const Color deepSlate = Color(0xFF1E293B);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryGreen.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Best Location:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(storeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryGreen), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total Bill:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('RM ${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primaryGreen)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFD1FAE5), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.savings, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text(savedAmt > 0 ? 'You save RM ${savedAmt.toStringAsFixed(2)}' : 'Best available price', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12)),
                ],
              ),
              if (pos != null)
                InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    final String queryTerm = Uri.encodeComponent('$storeName $address'.trim());
                    final String dirParam = '&origin=${originPos.latitude},${originPos.longitude}';
                    final Uri geoUrl = Uri.parse('geo:${pos.latitude},${pos.longitude}?q=$queryTerm');
                    final Uri webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1$dirParam&destination=$queryTerm');
                    try {
                      bool launched = await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
                      if (!launched) await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                    } catch (e) { debugPrint("Map error: $e"); }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: deepSlate, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Navigate 🚗', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          )
        ],
      ),
    );
  }
}