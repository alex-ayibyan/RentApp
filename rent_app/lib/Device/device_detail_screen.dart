import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String? deviceId;

  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  late Future<Map<String, dynamic>> _deviceFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isRenting = false;

  @override
  void initState() {
    super.initState();
    _deviceFuture = _fetchDeviceDetails();
  }

  Future<Map<String, dynamic>> _fetchDeviceDetails() async {
    if (widget.deviceId == null || widget.deviceId!.isEmpty) {
      throw Exception("Device ID is required");
    }

    try {
      var deviceSnapshot = await _firestore
          .collection('devices')
          .doc(widget.deviceId)
          .get();
      
      if (!deviceSnapshot.exists) {
        throw Exception("Device not found");
      }
      
      var data = deviceSnapshot.data() ?? {};
      data['id'] = widget.deviceId;
      
      if (data['ownerId'] != null) {
        try {
          var ownerSnapshot = await _firestore
              .collection('users')
              .doc(data['ownerId'])
              .get();
          
          if (ownerSnapshot.exists) {
            data['ownerData'] = ownerSnapshot.data();
          }
        } catch (e) {
          debugPrint("Error fetching owner details: $e");
        }
      }
      
      return data;
    } catch (e) {
      debugPrint("Error fetching device details: $e");
      rethrow;
    }
  }

  Future<void> _rentDevice(Map<String, dynamic> device) async {
  if (_selectedStartDate == null || _selectedEndDate == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select rental dates')),
    );
    return;
  }

  final scaffoldMessenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  
  setState(() => _isRenting = true);

  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    final days = _selectedEndDate!.difference(_selectedStartDate!).inDays + 1;
    final totalCost = days * (device['pricePerDay'] ?? 0.0);

    await _firestore.collection('rentals').add({
      'deviceId': widget.deviceId,
      'deviceName': device['name'],
      'renterId': currentUser.uid,
      'renterEmail': currentUser.email,
      'ownerId': device['ownerId'],
      'startDate': Timestamp.fromDate(_selectedStartDate!),
      'endDate': Timestamp.fromDate(_selectedEndDate!),
      'totalCost': totalCost,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Rental request submitted')),
    );
    
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) navigator.pop();
  } catch (e) {
    debugPrint("Error renting device: $e");
    
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  } finally {
    if (mounted) setState(() => _isRenting = false);
  }
}

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = DateTimeRange(
      start: DateTime.now(),
      end: DateTime.now().add(const Duration(days: 7)),
    );
    
    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedStartDate != null && _selectedEndDate != null
          ? DateTimeRange(start: _selectedStartDate!, end: _selectedEndDate!)
          : initialDateRange,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.deepOrangeAccent,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _selectedStartDate = pickedRange.start;
        _selectedEndDate = pickedRange.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deviceId == null || widget.deviceId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Device Details')),
        body: const Center(child: Text('No device selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Details'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _deviceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Device not found'));
          }

          var device = snapshot.data!;
          return _buildDeviceDetails(device);
        },
      ),
    );
  }

  Widget _buildDeviceDetails(Map<String, dynamic> device) {
    final isCurrentUserOwner = _auth.currentUser?.uid == device['ownerId'];
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey.shade200,
            child: device['image'] != null && device['image'].toString().isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        device['image'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Error loading image: $error');
                          return Icon(
                            Icons.devices_other,
                            size: 80,
                            color: Colors.deepOrangeAccent.shade200,
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
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Icon(
                    Icons.devices_other,
                    size: 80,
                    color: Colors.deepOrangeAccent.shade200,
                  ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        device['name'] ?? 'Unknown device',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.deepOrangeAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '€${(device['pricePerDay'] ?? 0.0).toStringAsFixed(2)}/day',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  device['description'] ?? 'No description available',
                  style: const TextStyle(fontSize: 16),
                ),
                
                const SizedBox(height: 24),
                
                if (device['location'] != null) ...[
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
                      const Icon(Icons.location_on, color: Colors.deepOrangeAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          device['address'] ?? 'Location available',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/device-map',
                        arguments: {'focusDeviceId': device['id']},
                      );
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('View on Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                const Text(
                  'Owner',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey.shade300,
                      radius: 20,
                      child: const Icon(Icons.person, color: Colors.black54),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        device['ownerData'] != null && device['ownerData']['name'] != null
                            ? device['ownerData']['name']
                            : device['ownerId'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                if (!isCurrentUserOwner) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  const Text(
                    'Rent This Device',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  ListTile(
                    title: const Text('Select Rental Period'),
                    subtitle: _selectedStartDate != null && _selectedEndDate != null
                        ? Text(
                            '${dateFormat.format(_selectedStartDate!)} - ${dateFormat.format(_selectedEndDate!)}',
                            style: const TextStyle(color: Colors.deepOrangeAccent),
                          )
                        : const Text('Tap to select dates'),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    onTap: () => _selectDateRange(context),
                  ),
                  
                  if (_selectedStartDate != null && _selectedEndDate != null) ...[
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rental Summary',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'Duration',
                            '${_selectedEndDate!.difference(_selectedStartDate!).inDays + 1} days'
                          ),
                          _buildSummaryRow(
                            'Daily Rate',
                            '€${(device['pricePerDay'] ?? 0.0).toStringAsFixed(2)}'
                          ),
                          const Divider(),
                          _buildSummaryRow(
                            'Total Cost',
                            '€${((_selectedEndDate!.difference(_selectedStartDate!).inDays + 1) * (device['pricePerDay'] ?? 0.0)).toStringAsFixed(2)}',
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isRenting ? null : () => _rentDevice(device),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrangeAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isRenting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Request to Rent',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ] else ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  const Text(
                    'Your Device',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/edit-device',
                              arguments: device['id'],
                            ).then((_) {
                              setState(() {
                                _deviceFuture = _fetchDeviceDetails();
                              });
                            });
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Device'),
                                content: const Text(
                                  'Are you sure you want to delete this device? '
                                  'This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      final navigator = Navigator.of(context);
                                      try {
                                        await _firestore
                                            .collection('devices')
                                            .doc(widget.deviceId)
                                            .delete();

                                        scaffoldMessenger.showSnackBar(
                                          const SnackBar(content: Text('Device deleted')),
                                        );
                                        if (mounted) {
                                          navigator.pop();
                                        }
                                      } catch (e) {
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(content: Text('Error: ${e.toString()}')),
                                        );
                                      }
                                    },
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}