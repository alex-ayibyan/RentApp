import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  LocationPickerScreenState createState() => LocationPickerScreenState();
}

class LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _center;
  LatLng? _pickedLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

Future<void> _getCurrentLocation() async {
  try {
    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
    );

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: locationSettings,
    );

    setState(() {
      _center = LatLng(position.latitude, position.longitude);
    });
  } catch (e) {
    debugPrint('Error getting location: $e');
  }
}


  void _selectLocation(LatLng position) {
    setState(() {
      _pickedLocation = position;
    });
  }

  void _confirmLocation() {
    if (_pickedLocation != null) {
      Navigator.of(context).pop(_pickedLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick a Location'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            onPressed: _confirmLocation,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _center == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: _center!,
                initialZoom: 13,
                onTap: (tapPosition, latlng) => _selectLocation(latlng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                ),
                if (_pickedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80,
                        height: 80,
                        point: _pickedLocation!,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 50,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
