import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:location/location.dart' as location_service;
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import 'location_picker_screen.dart'; // <-- Make sure this import is correct

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  AddDeviceScreenState createState() => AddDeviceScreenState();
}

class AddDeviceScreenState extends State<AddDeviceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  File? _imageFile;
  bool _isLoading = false;
  GeoPoint? _location;
  String? _address;

  final List<String> _categories = [
    'Electronics', 'Tools', 'Furniture', 'Vehicles', 'Sports Equipment',
    'Clothing', 'Books', 'Kitchen Appliances', 'Musical Instruments', 'Other'
  ];

  String _selectedCategory = 'Electronics';

  bool _addLocation = false; // <-- New: Whether user wants to add location

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${_auth.currentUser!.uid}';
      final Reference storageRef = _storage.ref().child('device_images/$fileName');
      await storageRef.putFile(_imageFile!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final locationService = location_service.Location();
      bool serviceEnabled = await locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await locationService.requestService();
        if (!serviceEnabled) {
          _showSnackBar('Location services are disabled');
          setState(() => _isLoading = false);
          return;
        }
      }

      var permissionStatus = await locationService.hasPermission();
      if (permissionStatus == location_service.PermissionStatus.denied) {
        permissionStatus = await locationService.requestPermission();
        if (permissionStatus != location_service.PermissionStatus.granted) {
          _showSnackBar('Location permission denied');
          setState(() => _isLoading = false);
          return;
        }
      }

      final locationData = await locationService.getLocation();
      final GeoPoint geoPoint = GeoPoint(locationData.latitude!, locationData.longitude!);

      List<Placemark> placemarks = await placemarkFromCoordinates(
        locationData.latitude!,
        locationData.longitude!,
      );

      String fullAddress = 'Unknown location';
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        fullAddress = '${place.street}, ${place.locality}, ${place.country}';
      }

      setState(() {
        _location = geoPoint;
        _address = fullAddress;
        _isLoading = false;
      });

      _showSnackBar('Location added: $_address');
    } catch (e) {
      debugPrint('Error getting location: $e');
      _showSnackBar('Failed to get location');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectLocationManually() async {
    LatLng? selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(),
      ),
    );

    if (selectedLocation != null) {
      GeoPoint geoPoint = GeoPoint(selectedLocation.latitude, selectedLocation.longitude);

      List<Placemark> placemarks = await placemarkFromCoordinates(
        selectedLocation.latitude,
        selectedLocation.longitude,
      );

      String fullAddress = 'Unknown location';
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        fullAddress = '${place.street}, ${place.locality}, ${place.country}';
      }

      setState(() {
        _location = geoPoint;
        _address = fullAddress;
      });

      _showSnackBar('Location selected: $_address');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveDevice() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? imageUrl = await _uploadImage();

      Map<String, dynamic> deviceData = {
        'name': _nameController.text.trim(),
        'available': true,
        'description': _descriptionController.text.trim(),
        'pricePerDay': double.parse(_priceController.text.trim()),
        'ownerId': _auth.currentUser!.uid,
        'ownerEmail': _auth.currentUser!.email,
        'createdAt': Timestamp.now(),
        'image': imageUrl,
        'category': _selectedCategory,
      };

      if (_addLocation && _location != null) {
        deviceData['location'] = _location;
        deviceData['address'] = _address;
      }

      await _firestore.collection('devices').add(deviceData);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error saving device: $e');
      _showSnackBar('Failed to save device');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Device', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 48, color: Colors.grey.shade600),
                            const SizedBox(height: 8),
                            Text('Add Device Photo', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  prefixIcon: Icon(Icons.devices),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a device name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories.map((String category) => DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                )).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) setState(() => _selectedCategory = newValue);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price per Day (€)',
                  prefixIcon: Icon(Icons.euro),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a price';
                  try {
                    if (double.parse(value) <= 0) return 'Price must be greater than zero';
                  } catch (e) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 🔥 Add location toggle switch
              SwitchListTile(
                title: const Text('Add Location?'),
                value: _addLocation,
                onChanged: (bool value) {
                  setState(() => _addLocation = value);
                },
              ),

              if (_addLocation) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Use Current Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrangeAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectLocationManually,
                        icon: const Icon(Icons.map),
                        label: const Text('Select on Map'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrangeAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrangeAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'SAVE DEVICE',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
