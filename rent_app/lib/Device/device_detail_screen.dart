import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rent_app/Device/device_edit_screen.dart';
import 'dart:convert'; // For base64Decode

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;

  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  DeviceDetailScreenState createState() => DeviceDetailScreenState();
}

class DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _deviceData;
  bool _isLoading = true;
  bool _isOwner = false;

  final Map<String, IconData> _categoryIcons = {
    'Electronics': Icons.devices,
    'Tools': Icons.handyman,
    'Furniture': Icons.chair,
    'Vehicles': Icons.directions_car,
    'Sports Equipment': Icons.sports_basketball,
    'Clothing': Icons.checkroom,
    'Books': Icons.menu_book,
    'Kitchen Appliances': Icons.kitchen,
    'Musical Instruments': Icons.music_note,
    'Other': Icons.category,
  };

  @override
  void initState() {
    super.initState();
    _loadDeviceData();
  }

  Future<void> _loadDeviceData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final docSnapshot =
          await _firestore.collection('devices').doc(widget.deviceId).get();

      if (!mounted) return;

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        data['id'] = docSnapshot.id;

        if (mounted) {
          setState(() {
            _deviceData = data;
            _isOwner = data['ownerId'] == _auth.currentUser?.uid;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          _showSnackBar('Device not found');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error loading device: $e');
      if (mounted) {
        _showSnackBar('Failed to load device details');
        setState(() => _isLoading = false);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _deleteDevice() async {
    if (!_isOwner) return;

    final bool confirm =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Delete Device'),
                content: const Text(
                  'Are you sure you want to delete this device? This action cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('DELETE'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('devices').doc(widget.deviceId).delete();
      if (!mounted) return;
      _showSnackBar('Device deleted successfully');
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error deleting device: $e');
      _showSnackBar('Failed to delete device');
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCustomCalendarDialog() async {
    final List<DateTime> bookedDates = await _getReservedDates();

    showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (context) {
        DateTime? startDate;
        DateTime? endDate;
        DateTime focusedDay = DateTime.now();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select reservation dates'),
              content: SizedBox(
                height: 400,
                width: 350,
                child: TableCalendar(
                  firstDay: DateTime.now(),
                  lastDay: DateTime.now().add(const Duration(days: 730)),
                  focusedDay: focusedDay,
                  calendarFormat: CalendarFormat.month,
                  rangeSelectionMode: RangeSelectionMode.toggledOn,
                  rangeStartDay: startDate,
                  rangeEndDay: endDate,
                  onRangeSelected: (start, end, newFocusedDay) {
                    setState(() {
                      startDate = start;
                      endDate = end;
                      focusedDay = newFocusedDay;
                    });
                  },
                  selectedDayPredicate: (day) {
                    return startDate != null &&
                        endDate != null &&
                        day.isAfter(
                          startDate!.subtract(const Duration(days: 1)),
                        ) &&
                        day.isBefore(endDate!.add(const Duration(days: 1)));
                  },
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      bool isBooked = bookedDates.contains(
                        DateTime(day.year, day.month, day.day),
                      );
                      return Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isBooked ? Colors.red : null,
                            fontWeight:
                                isBooked ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (startDate == null || endDate == null) {
                      _showSnackBar("Please select a date range.");
                      return;
                    }

                    final overlap = bookedDates.any(
                      (d) => !d.isBefore(startDate!) && !d.isAfter(endDate!),
                    );
                    if (overlap) {
                      _showSnackBar("Selected range contains booked dates.");
                      return;
                    }

                    await _makeReservation(
                      DateTimeRange(start: startDate!, end: endDate!),
                    );
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                    _showSnackBar("Reservation successful.");
                  },
                  child: const Text('Reserve'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('MMM d, yyyy').format(timestamp.toDate());
  }

  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.category;
    return _categoryIcons[category] ?? Icons.category;
  }

  Color _getCategoryColor(String? category) {
    if (category == null) return Colors.green;

    final Map<String, Color> categoryColors = {
      'Electronics': Colors.blue,
      'Tools': Colors.brown,
      'Furniture': Colors.teal,
      'Vehicles': Colors.red,
      'Sports Equipment': Colors.green,
      'Clothing': Colors.purple,
      'Books': Colors.indigo,
      'Kitchen Appliances': Colors.amber,
      'Musical Instruments': Colors.deepPurple,
    };

    return categoryColors[category] ?? Colors.green;
  }

  double? _getLatitude(dynamic location) {
    if (location == null) return null;
    if (location is GeoPoint) {
      return location.latitude;
    } else if (location is Map) {
      return (location['latitude'] as num?)?.toDouble();
    }
    return null;
  }

  double? _getLongitude(dynamic location) {
    if (location == null) return null;
    if (location is GeoPoint) {
      return location.longitude;
    } else if (location is Map) {
      return (location['longitude'] as num?)?.toDouble();
    }
    return null;
  }

  void _showReservationDialog() {
    _showCustomCalendarDialog();
  }

  Future<List<DateTime>> _getReservedDates() async {
    final reservations =
        await _firestore
            .collection('reservations')
            .where('deviceId', isEqualTo: widget.deviceId)
            .where('status', whereIn: ['approved', 'pending'])
            .get();

    List<DateTime> reservedDates = [];
    for (var doc in reservations.docs) {
      final start = (doc['startDate'] as Timestamp).toDate();
      final end = (doc['endDate'] as Timestamp).toDate();

      for (
        DateTime d = start;
        d.isBefore(end.add(const Duration(days: 1)));
        d = d.add(const Duration(days: 1))
      ) {
        reservedDates.add(DateTime(d.year, d.month, d.day));
      }
    }

    return reservedDates;
  }

  Future<void> _makeReservation(DateTimeRange range) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final deviceOwnerId = _deviceData!['ownerId'];
    final deviceName = _deviceData!['name'];
    final pricePerDay = _deviceData!['pricePerDay'];

    final days = range.end.difference(range.start).inDays + 1;
    final totalPrice = pricePerDay * days;

    await _firestore.collection('reservations').add({
      'deviceId': widget.deviceId,
      'deviceName': deviceName,
      'userId': user.uid,
      'renterId': user.uid,
      'renterEmail': user.email,
      'ownerId': deviceOwnerId,
      'startDate': Timestamp.fromDate(range.start),
      'endDate': Timestamp.fromDate(range.end),
      'totalPrice': totalPrice,
      'pricePerDay': pricePerDay,
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });
  }

  Widget _buildDetailImage() {
    if (_deviceData!['imageBase64'] != null && 
        _deviceData!['imageBase64'].toString().isNotEmpty) {
      try {
        return Container(
          height: 250,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
          ),
          child: Image.memory(
            base64Decode(_deviceData!['imageBase64']),
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading base64 image: $error');
              return Center(
                child: Icon(
                  Icons.broken_image,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
              );
            },
          ),
        );
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        return Container(
          height: 200,
          color: Colors.grey.shade200,
          child: Center(
            child: Icon(
              Icons.broken_image,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
        );
      }
    }
    
    else if (_deviceData!['image'] != null &&
             _deviceData!['image'].toString().isNotEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
        ),
        child: Image.network(
          _deviceData!['image'],
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading network image: $error');
            return Center(
              child: Icon(
                Icons.broken_image,
                size: 64,
                color: Colors.grey.shade400,
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      );
    }
    
    else {
      return Container(
        height: 200,
        color: Colors.grey.shade200,
        child: Center(
          child: Icon(
            Icons.devices,
            size: 64,
            color: Colors.grey.shade400,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? category = _deviceData?['category'];
    final Color categoryColor = _getCategoryColor(category);

    final dynamic locationData = _deviceData?['location'];
    final double? latitude = _getLatitude(locationData);
    final double? longitude = _getLongitude(locationData);
    final bool hasValidLocation = latitude != null && longitude != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _deviceData?['name'] ?? 'Device Details',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black87,
        actions: [
          if (_isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Edit device',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => DeviceEditScreen(
                          deviceId: widget.deviceId,
                          existingData: _deviceData!,
                        ),
                  ),
                );

                if (result == true) {
                  _loadDeviceData();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteDevice,
              tooltip: 'Delete device',
            ),
          ],
        ],
      ),

      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _deviceData == null
              ? const Center(child: Text('Device not found'))
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        _buildDetailImage(),

                        if (category != null)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getCategoryIcon(category),
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    category,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _deviceData!['name'] ?? 'Unknown device',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (_deviceData!['pricePerDay'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '€${_deviceData!['pricePerDay'].toStringAsFixed(2)}/day',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          if (category != null)
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: categoryColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: categoryColor,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: categoryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(category),
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Category',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: categoryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _deviceData!['description'] ??
                                'No description available',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 24),

                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Owner',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _deviceData!['ownerEmail'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          if (_deviceData!['createdAt'] != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Added on',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(_deviceData!['createdAt']),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                          const SizedBox(height: 24),

                          if (_deviceData!['available'] != null &&
                              _deviceData!['available'] is bool)
                            Row(
                              children: [
                                Icon(
                                  _deviceData!['available'] == true
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  size: 20,
                                  color:
                                      _deviceData!['available'] == true
                                          ? Colors.green
                                          : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _deviceData!['available'] == true
                                      ? 'Available'
                                      : 'Not Available',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            )
                          else
                            const Text(
                              'Availability info not provided.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),

                          if (hasValidLocation) ...[
                            const SizedBox(height: 24),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Location',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: categoryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _deviceData!['address'] ??
                                            'Location available',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  height: 200,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: FlutterMap(
                                    options: MapOptions(
                                      initialCenter: LatLng(
                                        latitude,
                                        longitude,
                                      ),
                                      initialZoom: 13.0,
                                      interactionOptions:
                                          const InteractionOptions(
                                            flags:
                                                InteractiveFlag.all &
                                                ~InteractiveFlag.rotate,
                                          ),
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                                        subdomains: const ['a', 'b', 'c'],
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            width: 40.0,
                                            height: 40.0,
                                            point: LatLng(latitude, longitude),
                                            child: Icon(
                                              Icons.location_on,
                                              color: categoryColor,
                                              size: 40,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      bottomNavigationBar:
          _isOwner || _deviceData == null
              ? null
              : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ElevatedButton(
                    onPressed:
                        _deviceData!['available'] == true
                            ? _showReservationDialog
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _deviceData!['available'] == true
                              ? _getCategoryColor(category)
                              : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text(
                      _deviceData!['available'] == true
                          ? 'Make Reservation'
                          : 'Not Available',
                    ),
                  ),
                ),
              ),
    );
  }
}