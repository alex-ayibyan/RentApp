import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rent_app/Device/add_device_screen.dart';
import 'package:rent_app/Device/device_detail_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rent_app/map_screen.dart';
import 'package:rent_app/reservation/reservations_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late User _user;
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _filteredDevices = [];
  bool _isLoading = true;

  bool _filterByLocation = false;
  double _distanceFilter = 5.0;
  Position? _currentPosition;

  Position? _filterCenter;
  double _filterRadius = 5000;
  bool _locationFilterEnabled = false;

  final List<String> _categories = [
    'All',
    'Electronics',
    'Tools',
    'Furniture',
    'Vehicles',
    'Sports Equipment',
    'Clothing',
    'Books',
    'Kitchen Appliances',
    'Musical Instruments',
    'Other',
  ];

  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser!;
    _loadDevices();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _filterCenter = position;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      _devices = await _fetchDevices();
      _applyFilters();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDevices() async {
    try {
      var snapshot = await _firestore.collection('devices').get();
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        if (data['category'] == null) {
          data['category'] = 'Other';
        }
        return data;
      }).toList();
    } catch (e) {
      debugPrint("Error fetching devices: $e");
      return [];
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> devices = List.from(_devices);

    if (_selectedCategory != 'All') {
      devices =
          devices
              .where((device) => device['category'] == _selectedCategory)
              .toList();
    }

    if (_filterByLocation && _currentPosition != null) {
      devices =
          devices.where((device) {
            if (device['location'] == null) return false;
            GeoPoint geoPoint = device['location'];
            double distanceInMeters = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              geoPoint.latitude,
              geoPoint.longitude,
            );
            return distanceInMeters <= _distanceFilter * 1000;
          }).toList();
    }

    setState(() {
      _filteredDevices = devices;
    });
  }

  void _filterDevicesByCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _applyFilters();
  }

  Future<void> _logOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  String _formatUsername(String email) {
    return email
        .split('@')[0]
        .split('.')
        .map(
          (name) =>
              name.isNotEmpty ? name[0].toUpperCase() + name.substring(1) : '',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _formatUsername(_user.email ?? ""),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyReservationsScreen(),
                ),
              );
            },
            tooltip: 'Mijn Reservaties',
          ),
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => DeviceMapScreen(
                        locationFilterEnabled: _locationFilterEnabled,
                        filterCenter: _filterCenter,
                        filterRadius: _filterRadius,
                      ),
                ),
              );
            },
            tooltip: 'View devices on map',
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _logOut,
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter Chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _filterDevicesByCategory(category);
                      }
                    },
                    selectedColor: Colors.deepOrangeAccent,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                );
              },
            ),
          ),

          // Location Filter Switch and Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Filter by Distance'),
              Switch(
                value: _filterByLocation,
                onChanged: (value) {
                  setState(() {
                    _filterByLocation = value;
                    _locationFilterEnabled = _filterByLocation;
                  });
                  _applyFilters();
                },
                activeColor: Colors.deepOrangeAccent,
              ),
            ],
          ),
          if (_filterByLocation)
            Column(
              children: [
                Text('${_distanceFilter.toInt()} km'),
                Slider(
                  value: _distanceFilter,
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: '${_distanceFilter.toInt()} km',
                  onChanged: (value) {
                    setState(() {
                      _distanceFilter = value;
                      _filterRadius = _distanceFilter * 1000;
                    });
                    _applyFilters();
                  },
                ),
              ],
            ),

          // Device List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDevices,
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _devices.isEmpty
                      ? _buildEmptyState()
                      : _filteredDevices.isEmpty
                      ? _buildNoCategoryItemsState()
                      : _buildDeviceList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDeviceScreen()),
          );

          if (result == true) {
            _loadDevices();
          }
        },
        backgroundColor: Colors.deepOrangeAccent,
        tooltip: 'Add device',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.devices_other, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No devices available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first device using the + button',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadDevices,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrangeAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCategoryItemsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.category, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No $_selectedCategory items found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try selecting a different category or add new devices',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _filterDevicesByCategory('All'),
            icon: const Icon(Icons.all_inclusive),
            label: const Text('Show All Devices'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrangeAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      itemCount: _filteredDevices.length,
      itemBuilder: (context, index) {
        var device = _filteredDevices[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.black12, width: 0.5),
          ),
          elevation: 3,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => DeviceDetailScreen(deviceId: device['id']),
                ),
              ).then((_) => _loadDevices());
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        device['image'] != null &&
                                device['image'].toString().isNotEmpty
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                device['image'],
                                fit: BoxFit.cover,
                                width: 60,
                                height: 60,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('Error loading image: $error');
                                  return Icon(
                                    Icons.devices,
                                    color: Colors.deepOrangeAccent.shade200,
                                    size: 30,
                                  );
                                },
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      strokeWidth: 2,
                                    ),
                                  );
                                },
                              ),
                            )
                            : Icon(
                              Icons.devices,
                              color: Colors.deepOrangeAccent.shade200,
                              size: 30,
                            ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device['name'] ?? 'Unknown device',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (device['category'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              device['category'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        Text(
                          device['description'] ?? 'No description',
                          style: TextStyle(color: Colors.grey.shade600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        if (device['pricePerDay'] != null)
                          Text(
                            '€${device['pricePerDay'].toStringAsFixed(2)}/day',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrangeAccent,
                            ),
                          ),
                        if (device['available'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              device['available'] == true
                                  ? 'Available'
                                  : 'Not Available',
                              style: const TextStyle(
                                color: Colors.deepOrangeAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (device['location'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.deepOrangeAccent,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    device['address'] ?? 'Location available',
                                    style: const TextStyle(
                                      color: Colors.deepOrangeAccent,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
