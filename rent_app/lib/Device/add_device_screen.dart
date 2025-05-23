import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:location/location.dart' as location_service;
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import 'location_picker_screen.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  AddDeviceScreenState createState() => AddDeviceScreenState();
}

class AddDeviceScreenState extends State<AddDeviceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String? _imageBase64;
  
  bool _isLoading = false;
  bool _isAvailable = true;
  GeoPoint? _location;
  String? _address;

  final List<String> _categories = [
    'Electronics', 'Tools', 'Furniture', 'Vehicles', 'Sports Equipment',
    'Clothing', 'Books', 'Kitchen Appliances', 'Musical Instruments', 'Other'
  ];

  String _selectedCategory = 'Electronics';
  bool _addLocation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!kIsWeb)
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      
      if (image != null) {
        setState(() => _isLoading = true);
        
        try {
          Uint8List imageBytes = await image.readAsBytes();

          if (imageBytes.length > 1024 * 1024) {
            _showSnackBar('Image too large. Please select a smaller image.');
            setState(() => _isLoading = false);
            return;
          }
          
          String base64String = base64Encode(imageBytes);
          
          setState(() {
            _imageBase64 = base64String;
            _isLoading = false;
          });
          
          _showSnackBar('Image selected successfully (${(imageBytes.length / 1024).toStringAsFixed(1)}KB)');
          debugPrint('Image converted to base64, size: ${base64String.length} characters');
          
        } catch (e) {
          debugPrint('Error processing image: $e');
          _showSnackBar('Failed to process image');
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showSnackBar('Failed to pick image: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    if (kIsWeb) {
      _showSnackBar('Location services not fully supported on web');
      return;
    }

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
      debugPrint('Starting device save process...');

      Map<String, dynamic> deviceData = {
        'name': _nameController.text.trim(),
        'available': _isAvailable,
        'description': _descriptionController.text.trim(),
        'pricePerDay': double.parse(_priceController.text.trim()),
        'ownerId': _auth.currentUser!.uid,
        'ownerEmail': _auth.currentUser!.email,
        'createdAt': Timestamp.now(),
        'imageBase64': _imageBase64, // store base64 string directly
        'category': _selectedCategory,
      };

      if (_addLocation && _location != null) {
        deviceData['location'] = _location;
        deviceData['address'] = _address;
        debugPrint('Adding location data: ${_location?.latitude}, ${_location?.longitude}');
      }

      debugPrint('Saving device data to Firestore...');
      if (_imageBase64 != null) {
        debugPrint('Image data size: ${_imageBase64!.length} characters');
      }
      
      await _firestore.collection('devices').add(deviceData);
      
      debugPrint('Device saved successfully');
      _showSnackBar('Device saved successfully');

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error saving device: $e');
      if (e is FirebaseException) {
        debugPrint('Firebase error code: ${e.code}');
        debugPrint('Firebase error message: ${e.message}');
      }
      _showSnackBar('Failed to save device: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  bool get _hasImage => _imageBase64 != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Device', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing...'),
                ],
              ),
            )
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
                  child: _hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(_imageBase64!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 48, color: Colors.grey.shade600),
                            const SizedBox(height: 8),
                            Text('Add Device Photo', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              'Max size: 1MB',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),
              if (_hasImage)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Image selected',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _imageBase64 = null;
                          });
                        },
                        child: const Text('Remove', style: TextStyle(color: Colors.red)),
                      ),
                    ],
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

               Row(
                 children: [
                   const Icon(Icons.event_available, color: Colors.grey),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Text(
                       'Available',
                       style: TextStyle(fontSize: 16),
                     ),
                   ),
                   Switch(
                     value: _isAvailable,
                     activeColor: Colors.green,
                     onChanged: (value) {
                       setState(() {
                         _isAvailable = value;
                       });
                     },
                   ),
                 ],
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

              SwitchListTile(
                title: Text(kIsWeb ? 'Add Location (Not available on web)' : 'Add Location?'),
                value: _addLocation,
                onChanged: kIsWeb ? null : (bool value) {
                  setState(() => _addLocation = value);
                },
              ),

              if (_addLocation && !kIsWeb) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Use Current Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
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
                          backgroundColor: Colors.green,
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
                  backgroundColor: Colors.green,
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