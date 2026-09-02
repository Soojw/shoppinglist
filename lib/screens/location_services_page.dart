import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationServicesPage extends StatefulWidget {
  const LocationServicesPage({super.key});

  @override
  State<LocationServicesPage> createState() => _LocationServicesPageState();
}

class _LocationServicesPageState extends State<LocationServicesPage> {
  bool _enableGPS = true;
  double _searchRadius = 15.0;
  String _selectedPlace = 'Current GPS Location';

  final TextEditingController _searchController = TextEditingController();
  List<String> _savedPlaces = ['Current GPS Location'];

  final MapController _mapController = MapController();
  LatLng _mapCenter = const LatLng(3.140853, 101.693207);

  String _mapTooltip = 'Kuala Lumpur';
  String _resolvedFullAddress = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    List<String>? storedPlaces = prefs.getStringList('saved_places_list');
    if (storedPlaces != null && storedPlaces.isNotEmpty) {
      if (!storedPlaces.contains('Current GPS Location')) {
        storedPlaces.insert(0, 'Current GPS Location');
      }
      _savedPlaces = storedPlaces;
    } else {
      _savedPlaces = ['Current GPS Location'];
      await prefs.setStringList('saved_places_list', _savedPlaces);
    }

    setState(() {
      _searchRadius = prefs.getDouble('search_radius') ?? 15.0;
      _selectedPlace = prefs.getString('global_active_location') ?? 'Current GPS Location';
    });
  }

  Future<void> _saveRadius(double value) async {
    setState(() => _searchRadius = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('search_radius', value);
  }

  Future<void> _selectPlace(String place) async {
    setState(() => _selectedPlace = place);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global_active_location', place);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location switched to $place'), backgroundColor: const Color(0xFF059669), duration: const Duration(milliseconds: 800)));
    }
  }

  Future<void> _deletePlace(String place) async {
    bool? confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Place', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to remove "$place" from your saved places?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, elevation: 0),
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        )
    );

    if (confirm == true) {
      setState(() {
        _savedPlaces.remove(place);
        if (_selectedPlace == place) {
          _selectedPlace = 'Current GPS Location';
        }
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_places_list', _savedPlaces);
      await prefs.setString('global_active_location', _selectedPlace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Place removed successfully.'), backgroundColor: Colors.redAccent, duration: Duration(milliseconds: 800)));
      }
    }
  }


  Future<void> _performRealMapSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _mapTooltip = 'Searching...';
      _resolvedFullAddress = 'Searching...';
    });

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=my');
      final response = await http.get(url, headers: {'User-Agent': 'SmartShoppingDemoApp'});

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final place = data[0];
          final double lat = double.parse(place['lat']);
          final double lon = double.parse(place['lon']);
          final String displayName = place['display_name'];

          setState(() {
            _mapCenter = LatLng(lat, lon);
            _mapTooltip = query.toUpperCase();
            _resolvedFullAddress = displayName;
            _isSearching = false;
          });

          _mapController.move(_mapCenter, 16.0);
          return;
        }
      }
    } catch (e) {
      debugPrint('Geocoding Error: $e');
    }

    setState(() {
      _mapTooltip = query.toUpperCase();
      _resolvedFullAddress = '$query, Kuala Lumpur, Malaysia (Estimated)';
      _mapCenter = LatLng(_mapCenter.latitude + 0.01, _mapCenter.longitude + 0.01);
      _isSearching = false;
    });
    _mapController.move(_mapCenter, 13.0);
  }

  Future<void> _saveCustomLocation() async {
    if (_resolvedFullAddress.isEmpty || _resolvedFullAddress == 'Searching...') return;

    TextEditingController nameController = TextEditingController();
    String? customName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Save this place', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Confirm Address:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(_resolvedFullAddress, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Name (e.g., University)",
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, nameController.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), elevation: 0),
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        )
    );

    if (customName != null && customName.isNotEmpty) {
      String finalPlace = '$customName ($_resolvedFullAddress)';

      setState(() {
        if (!_savedPlaces.contains(finalPlace)) {
          _savedPlaces.add(finalPlace);
        }
        _selectedPlace = finalPlace;
        _searchController.clear();
        _resolvedFullAddress = '';
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_places_list', _savedPlaces);
      await prefs.setString('global_active_location', finalPlace);

      if (mounted) FocusScope.of(context).unfocus();
    }
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
        title: const Text('Location Services', style: TextStyle(color: deepSlate, fontWeight: FontWeight.bold)),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: SwitchListTile(
                activeColor: primaryGreen,
                title: const Text('Enable GPS Tracking', style: TextStyle(fontWeight: FontWeight.bold, color: deepSlate)),
                subtitle: const Text('Required for real-time navigation.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: _enableGPS,
                onChanged: (value) => setState(() => _enableGPS = value),
              ),
            ),
            const SizedBox(height: 32),

            const Text('Add a Custom Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: deepSlate)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: _performRealMapSearch,
                decoration: InputDecoration(
                  hintText: 'Search place (e.g., TAR UMT, KLCC)',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _isSearching ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: primaryGreen)),
                  ) : null,
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _mapCenter,
                              initialZoom: 13.0,
                              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'my.edu.tarc.smart_shopping_list',
                              ),
                            ],
                          ),

                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                                  child: Text(_mapTooltip, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                const Icon(Icons.arrow_drop_down, color: Colors.black87, size: 24, fill: 1.0),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _resolvedFullAddress.isEmpty ? 'Search a place above to locate' : _resolvedFullAddress,
                            style: TextStyle(
                              color: _resolvedFullAddress.isEmpty ? Colors.grey : deepSlate,
                              fontSize: 13,
                              fontWeight: _resolvedFullAddress.isEmpty ? FontWeight.normal : FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _resolvedFullAddress.isEmpty || _resolvedFullAddress == 'Searching...' ? null : _saveCustomLocation,
                          child: const Text('Save', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            const Text('Your Saved Places', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: deepSlate)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: _savedPlaces.map((place) {
                  bool isSelected = place == _selectedPlace;
                  IconData icon = place == 'Current GPS Location' ? Icons.my_location : Icons.place;

                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(icon, color: isSelected ? primaryGreen : Colors.grey),
                        title: Text(place, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? deepSlate : Colors.grey.shade700)),
                        onTap: () => _selectPlace(place),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected)
                              const Icon(Icons.check_circle, color: primaryGreen),
                            if (place != 'Current GPS Location') ...[
                              if (isSelected) const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deletePlace(place),
                              ),
                            ]
                          ],
                        ),
                      ),
                      if (place != _savedPlaces.last)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),

            const Text('Search Radius', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: deepSlate)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Find deals within:'),
                      Text('${_searchRadius.toInt()} km', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryGreen, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _searchRadius,
                    min: 1.0,
                    max: 50.0,
                    divisions: 49,
                    activeColor: primaryGreen,
                    inactiveColor: Colors.green.shade100,
                    label: '${_searchRadius.toInt()} km',
                    onChanged: _enableGPS ? (value) => setState(() => _searchRadius = value) : null,
                    onChangeEnd: (value) => _saveRadius(value),
                  ),
                  const Text('Stores outside this radius will be dynamically filtered from the map.', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}