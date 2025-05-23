import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class DeviceEditScreen extends StatefulWidget {
  final String deviceId;
  final Map<String, dynamic> existingData;

  const DeviceEditScreen({
    super.key,
    required this.deviceId,
    required this.existingData,
  });

  @override
  State<DeviceEditScreen> createState() => _DeviceEditScreenState();
}

class _DeviceEditScreenState extends State<DeviceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  bool _available = true;
  late String _selectedCategory;
  
  String? _imageBase64;
  bool _imageChanged = false;
  bool _isLoadingImage = false;

  final List<String> _categories = [
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

  final Map<String, Color> _categoryColors = {
    'Electronics': Colors.blue,
    'Tools': Colors.brown,
    'Furniture': Colors.teal,
    'Vehicles': Colors.red,
    'Sports Equipment': Colors.green,
    'Clothing': Colors.purple,
    'Books': Colors.indigo,
    'Kitchen Appliances': Colors.amber,
    'Musical Instruments': Colors.deepPurple,
    'Other': Colors.deepOrangeAccent,
  };

  Color _getCategoryColor(String? category) {
    return _categoryColors[category] ?? Colors.grey;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingData['name']);
    _descriptionController = TextEditingController(text: widget.existingData['description']);
    _priceController = TextEditingController(
      text: widget.existingData['pricePerDay']?.toString() ?? '',
    );
    _available = widget.existingData['available'] ?? true;
    _selectedCategory = widget.existingData['category'] ?? _categories.first;
    
    _loadExistingImage();
  }

  void _loadExistingImage() {
    if (widget.existingData['imageBase64'] != null && 
        widget.existingData['imageBase64'].toString().isNotEmpty) {
      _imageBase64 = widget.existingData['imageBase64'];
    }
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
        setState(() => _isLoadingImage = true);
        
        try {
          Uint8List imageBytes = await image.readAsBytes();
          
          if (imageBytes.length > 1024 * 1024) {
            _showSnackBar('Image too large. Please select a smaller image.');
            setState(() => _isLoadingImage = false);
            return;
          }
          
          String base64String = base64Encode(imageBytes);
          
          setState(() {
            _imageBase64 = base64String;
            _imageChanged = true;
            _isLoadingImage = false;
          });
          
          _showSnackBar('Image updated successfully (${(imageBytes.length / 1024).toStringAsFixed(1)}KB)');
          debugPrint('Image converted to base64, size: ${base64String.length} characters');
          
        } catch (e) {
          debugPrint('Error processing image: $e');
          _showSnackBar('Failed to process image');
          setState(() => _isLoadingImage = false);
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showSnackBar('Failed to pick image: ${e.toString()}');
      setState(() => _isLoadingImage = false);
    }
  }

  void _removeImage() {
    setState(() {
      _imageBase64 = null;
      _imageChanged = true;
    });
    _showSnackBar('Image removed');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      Map<String, dynamic> updateData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'pricePerDay': double.tryParse(_priceController.text) ?? 0.0,
        'available': _available,
        'category': _selectedCategory,
        'updatedAt': Timestamp.now(),
      };

      if (_imageChanged) {
        updateData['imageBase64'] = _imageBase64;
        updateData['image'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('devices')
          .doc(widget.deviceId)
          .update(updateData);

      if (mounted) {
        _showSnackBar('Device updated successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error updating device: $e');
      if (mounted) {
        _showSnackBar('Failed to update device: ${e.toString()}');
      }
    }
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Device Image',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: _isLoadingImage
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Processing image...'),
                    ],
                  ),
                )
              : _imageBase64 != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Image.memory(
                            base64Decode(_imageBase64!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 48, color: Colors.grey.shade600),
                                    const Text('Invalid image'),
                                  ],
                                ),
                              );
                            },
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                onPressed: _removeImage,
                                tooltip: 'Remove image',
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 48, color: Colors.grey.shade600),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add image',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Max size: 1MB',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
        
        if (_imageBase64 != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.edit),
                  label: const Text('Change Image'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _removeImage,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Remove', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add Image'),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Device', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  prefixIcon: Icon(Icons.devices),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price Per Day (€)',
                  prefixIcon: Icon(Icons.euro),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed < 0) return 'Enter a valid price';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _getCategoryColor(_selectedCategory),
                  border: Border.all(color: _getCategoryColor(_selectedCategory)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(Icons.category, color: _getCategoryColor(_selectedCategory)),
                    const SizedBox(width: 8),
                    Text(
                      _selectedCategory,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getCategoryColor(_selectedCategory),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                value: _available,
                onChanged: (value) => setState(() => _available = value),
                title: const Text('Available for rent'),
                subtitle: Text(_available ? 'Device is available' : 'Device is not available'),
                activeColor: Colors.green,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}