import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../models/cart_model.dart';

class RealStore {
  final String name;
  final String address;
  final LatLng position;
  final double distanceKm;
  final String displayPrice;

  RealStore({
    required this.name,
    required this.address,
    required this.position,
    required this.distanceKm,
    required this.displayPrice,
  });
}

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final Distance _distanceCalc = const Distance();
  final TextEditingController _searchController = TextEditingController();

  LatLng _mapCenter = const LatLng(3.140853, 101.693207);
  double _currentRadius = 15.0;
  String _currentPlaceName = 'Current Location';

  List<Marker> _mapMarkers = [];
  bool _isLoading = true;

  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;

  String _selectedStoreName = 'Select a store on the map';
  String _selectedStoreDistance = '--';
  String _selectedStoreStatus = 'Tap a marker';
  String _selectedStoreAddress = '';
  LatLng? _selectedStoreLatLng;

  static final Map<String, LatLng> _geoCache = {};

  String _lastActiveLocationSetting = 'UNSET';
  bool _isCheckingUpdates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkGlobalSettingsUpdates();
    }
  }

  Future<void> _checkGlobalSettingsUpdates() async {
    if (_isCheckingUpdates) return;
    _isCheckingUpdates = true;

    final prefs = await SharedPreferences.getInstance();
    double savedRadius = prefs.getDouble('search_radius') ?? 15.0;
    String activeSetting = prefs.getString('global_active_location') ?? 'Current GPS Location';

    if (_lastActiveLocationSetting == 'UNSET') {
      _lastActiveLocationSetting = activeSetting;
      _currentRadius = savedRadius;
      await _initializeMapData();
    } else if (savedRadius != _currentRadius || activeSetting != _lastActiveLocationSetting) {
      _currentRadius = savedRadius;
      _lastActiveLocationSetting = activeSetting;
      if (mounted) {
        setState(() {
          _isLoading = true;
          _resetSelection();
        });
      }
      await _initializeMapData();
    }

    _isCheckingUpdates = false;
  }

  Future<void> _initializeMapData() async {
    if (mounted) setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _currentRadius = prefs.getDouble('search_radius') ?? 15.0;

    String activeSetting = prefs.getString('global_active_location') ?? 'Current GPS Location';
    _lastActiveLocationSetting = activeSetting;
    _currentPlaceName = activeSetting.contains(' (') ? activeSetting.split(' (').first : activeSetting;

    if (activeSetting == 'Current GPS Location') {
      await _getCurrentLocation(isInit: true);
    } else {
      String addressToSearch = activeSetting;
      if (addressToSearch.contains('(')) {
        addressToSearch = addressToSearch.substring(addressToSearch.indexOf('(') + 1, addressToSearch.lastIndexOf(')'));
      }

      LatLng? coords = await _geocodeAddress('ACTIVE_PLACE', addressToSearch);
      if (coords != null) {
        _mapCenter = coords;
      } else {
        _mapCenter = const LatLng(3.140853, 101.693207);
      }

      if (mounted) {
        _mapController.move(_mapCenter, 14.0);
      }
      await _fetchRealPremisesFromCsv();
    }
  }

  Future<void> _performRealMapSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
      _searchResults = [];
    });

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=my');
      final response = await http.get(url, headers: {'User-Agent': 'SmartShoppingDemoApp'});

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _searchResults = data;
          _isSearching = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Geocoding Error: $e');
    }

    setState(() {
      _isSearching = false;
    });
  }

  Future<void> _selectSearchResult(dynamic place) async {
    final double lat = double.parse(place['lat']);
    final double lon = double.parse(place['lon']);
    String shortName = place['name'] ?? place['display_name'].split(',').first;

    setState(() {
      _mapCenter = LatLng(lat, lon);
      _currentPlaceName = shortName.toUpperCase();
      _showSearchResults = false;
      _searchController.clear();
      _resetSelection();
    });

    FocusScope.of(context).unfocus();
    _mapController.move(_mapCenter, 14.0);
    await _fetchRealPremisesFromCsv();
  }

  Future<void> _getCurrentLocation({bool isInit = false}) async {
    setState(() {
      _isSearching = true;
      _showSearchResults = false;
      _searchController.clear();
      _resetSelection();
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Denied');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Denied Forever');

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      if (position.latitude > 10.0 || position.latitude < 0.0 || position.longitude < 98.0 || position.longitude > 120.0) {
        _mapCenter = const LatLng(3.140853, 101.693207);
      } else {
        _mapCenter = LatLng(position.latitude, position.longitude);
      }

      if (mounted && !isInit) {
        _mapController.move(_mapCenter, 14.0);
      }

      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${_mapCenter.latitude}&lon=${_mapCenter.longitude}&format=json');
      final response = await http.get(url, headers: {'User-Agent': 'SmartShoppingDemoApp'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _currentPlaceName = 'Current Location';
        });
        if (!isInit && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('📍 ${data['display_name'] ?? 'Location detected'}', maxLines: 2, overflow: TextOverflow.ellipsis),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 2),
          ));
        }
      }
    } catch (e) {
      debugPrint("GPS Error: $e");
    }

    setState(() => _isSearching = false);
    await _fetchRealPremisesFromCsv();
  }

  void _resetSelection() {
    _selectedStoreName = 'Select a store on the map';
    _selectedStoreDistance = '--';
    _selectedStoreStatus = 'Tap a marker';
    _selectedStoreAddress = '';
    _selectedStoreLatLng = null;
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
      final response = await http.get(url, headers: {'User-Agent': 'SmartShoppingRealGeoApp'});

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final pos = LatLng(lat, lon);
          _geoCache[searchAddr] = pos;
          return pos;
        }
      }
    } catch (e) {
      debugPrint("Geocoding failed for $searchAddr: $e");
    }
    return null;
  }

  Future<void> _fetchRealPremisesFromCsv() async {
    final prefs = await SharedPreferences.getInstance();
    _currentRadius = prefs.getDouble('search_radius') ?? 15.0;

    final List<CartItemModel> cartItems = await DatabaseService().getCartItems();
    bool hasItemsInCart = cartItems.isNotEmpty;

    int priceColIndex = 3, itemNameColIndex = 4, storeNameColIndex = 8, addressColIndex = 9, stateColIndex = 11;

    Map<String, double> storeTotalBills = {};
    Map<String, String> storeAddresses = {};

    try {
      final String url = 'https://gist.githubusercontent.com/Soojw/75bc56ef66c5827c0b4a8c05a831d4d6/raw/final_data.csv?v=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<String> rows = response.body.split('\n');
        for (int i = 1; i < rows.length; i++) {
          String row = rows[i].trim();
          if (row.isEmpty) continue;
          List<String> cols = _parseCsvRow(row);
          if (cols.length <= stateColIndex) continue;

          String storeName = cols[storeNameColIndex].trim();
          String itemName = cols[itemNameColIndex].trim();
          double realPrice = double.tryParse(cols[priceColIndex].trim()) ?? 0.0;
          String searchAddr = '$storeName ${cols[addressColIndex].trim()} ${cols[stateColIndex].trim()}'.trim();

          storeAddresses[storeName] = searchAddr;

          if (hasItemsInCart) {
            int cartQuantity = 0;
            bool isInCart = false;
            for (var cartItem in cartItems) {
              if (cartItem.itemName.toLowerCase().trim() == itemName.toLowerCase().trim()) {
                isInCart = true;
                cartQuantity = cartItem.quantity;
                break;
              }
            }
            if (isInCart) {
              storeTotalBills[storeName] = (storeTotalBills[storeName] ?? 0.0) + (realPrice * cartQuantity);
            }
          } else {
            if (!storeTotalBills.containsKey(storeName)) {
              storeTotalBills[storeName] = 0.0;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("CSV fetch failed: $e");
    }

    List<RealStore> resolvedStores = [];

    for (var entry in storeTotalBills.entries) {
      String storeName = entry.key;
      double totalPrice = entry.value;
      String searchAddr = storeAddresses[storeName] ?? storeName;

      LatLng? realPos = await _geocodeAddress(storeName, searchAddr);

      if (realPos != null) {
        double distanceKm = _distanceCalc.as(LengthUnit.Kilometer, _mapCenter, realPos);

        if (distanceKm <= _currentRadius) {
          String displayPrice = '';

          if (hasItemsInCart && totalPrice > 0) {
            displayPrice = 'RM ${totalPrice.toStringAsFixed(2)}';
          } else if (hasItemsInCart && totalPrice == 0) {
            continue;
          }

          resolvedStores.add(RealStore(
            name: storeName,
            address: searchAddr,
            position: realPos,
            distanceKm: distanceKm,
            displayPrice: displayPrice,
          ));
        }
      }
    }

    List<Marker> markers = resolvedStores.map((store) {
      return _buildPillMarker(store);
    }).toList();

    if (mounted) {
      setState(() {
        _mapMarkers = markers;
        _isLoading = false;
      });
    }
  }

  Marker _buildPillMarker(RealStore store) {
    bool hasPrice = store.displayPrice.isNotEmpty;
    return Marker(
      point: store.position,
      width: 200,
      height: 60,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStoreName = store.name;
            _selectedStoreDistance = '${store.distanceKm.toStringAsFixed(1)} km away';
            _selectedStoreStatus = 'Open now';
            _selectedStoreAddress = store.address;
            _selectedStoreLatLng = store.position;
          });
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      store.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (hasPrice) ...[
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0), child: Text('|', style: TextStyle(color: Colors.white54, fontSize: 12))),
                    Text(store.displayPrice, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  ]
                ],
              ),
            ),
            Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _checkGlobalSettingsUpdates();

    const Color primaryGreen = Color(0xFF059669);
    const Color deepSlate = Color(0xFF1E293B);

    String displayPlace = _currentPlaceName;
    if (displayPlace.length > 12) {
      displayPlace = '${displayPlace.substring(0, 10)}...';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: primaryGreen),
            SizedBox(height: 16),
            Text('Locating stores from data...', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500))
          ],
        ),
      )
          : Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _currentRadius < 10 ? 12.0 : 11.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'my.edu.tarc.smart_shopping_list',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _mapCenter,
                    width: 40, height: 40,
                    child: const Icon(Icons.my_location, color: Colors.blueAccent, size: 36),
                  )
                ],
              ),
              MarkerLayer(markers: _mapMarkers),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 10.0, left: 16.0, right: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: _performRealMapSearch,
                      decoration: InputDecoration(
                        hintText: 'Search near $displayPlace (${_currentRadius.toInt()}km)',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: GestureDetector(
                            onTap: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('global_active_location', 'Current GPS Location');
                              await prefs.setString('selected_place', 'Current GPS Location');
                              _getCurrentLocation();
                            },
                            child: Container(
                              decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
                              child: _isSearching && !_showSearchResults
                                  ? const Padding(padding: EdgeInsets.all(4.0), child: CircularProgressIndicator(strokeWidth: 2, color: primaryGreen))
                                  : const Icon(Icons.my_location, color: primaryGreen, size: 20),
                            ),
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  if (_showSearchResults)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                          border: Border.all(color: primaryGreen.withOpacity(0.3))
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_isSearching ? 'Searching...' : 'Select a location', style: const TextStyle(fontWeight: FontWeight.bold, color: deepSlate)),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => setState(() => _showSearchResults = false),
                                )
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          if (_isSearching)
                            const Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator(color: primaryGreen))
                          else if (_searchResults.isEmpty)
                            const Padding(padding: EdgeInsets.all(24.0), child: Text('No results found.', style: TextStyle(color: Colors.grey)))
                          else
                            Flexible(
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _searchResults.length,
                                separatorBuilder: (ctx, i) => const Divider(height: 1),
                                itemBuilder: (ctx, index) {
                                  final place = _searchResults[index];
                                  return ListTile(
                                    leading: const Icon(Icons.location_on, color: primaryGreen),
                                    title: Text(place['display_name'], style: const TextStyle(fontSize: 13, color: deepSlate), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    onTap: () => _selectSearchResult(place),
                                  );
                                },
                              ),
                            )
                        ],
                      ),
                    )
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 20, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(_selectedStoreName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: deepSlate), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (_selectedStoreStatus != 'Tap a marker')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(12)),
                          child: Text(_selectedStoreStatus, style: const TextStyle(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                      const SizedBox(width: 4),
                      Text(_selectedStoreDistance, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(width: 20),
                      const Icon(Icons.access_time, color: Colors.grey, size: 20),
                      const SizedBox(width: 4),
                      const Text('Closes 10pm', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_selectedStoreLatLng == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Please tap a store on the map first.'),
                            backgroundColor: Colors.redAccent,
                          ));
                          return;
                        }

                        final double lat = _selectedStoreLatLng!.latitude;
                        final double lng = _selectedStoreLatLng!.longitude;
                        final String queryTerm = Uri.encodeComponent('${_selectedStoreName} ${_selectedStoreAddress}'.trim());

                        final Uri geoUrl = Uri.parse('geo:$lat,$lng?q=$queryTerm');
                        final Uri webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$queryTerm');

                        try {
                          bool launched = await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
                          if (!launched) {
                            await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Could not open Maps app.'),
                              backgroundColor: Colors.redAccent,
                            ));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      child: const Text('Get directions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}