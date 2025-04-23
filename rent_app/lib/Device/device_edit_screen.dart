import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  bool _available = true;
  late String _selectedCategory;

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
      await FirebaseFirestore.instance.collection('devices').doc(widget.deviceId).update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'pricePerDay': double.tryParse(_priceController.text) ?? 0.0,
        'available': _available,
        'category': _selectedCategory,
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device updated successfully')),
        );
        Navigator.pop(context, true); // Optionally return true to signal success
      }
    } catch (e) {
      debugPrint('Error updating device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update device')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Device'),
        backgroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Device Name'),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price Per Day (€)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                  border: OutlineInputBorder(),
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
                  color: _getCategoryColor(_selectedCategory).withOpacity(0.1),
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
                title: const Text('Available'),
                activeColor: Colors.green,
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrangeAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Save Changes',
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
