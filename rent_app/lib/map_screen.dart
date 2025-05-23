import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceMapScreen extends StatefulWidget {
  final bool locationFilterEnabled;
  final Position? filterCenter;
  final double? filterRadius; // in meters

  const DeviceMapScreen({
    super.key,
    this.locationFilterEnabled = false,
    this.filterCenter,
    this.filterRadius,
  });

  @override
  DeviceMapScreenState createState() => DeviceMapScreenState();
}

class DeviceMapScreenState extends State<DeviceMapScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _devices = [];
  bool isLoading = true;

  final LatLng _defaultCenter = LatLng(51.2297, 4.4180); // Antwerp
  bool _locationFilterEnabled = false;
  LatLng? _filterCenter;
  double _filterRadius = 5000; // default 5km

  @override
  void initState() {
    super.initState();
    _locationFilterEnabled = widget.locationFilterEnabled;
    _filterCenter = widget.filterCenter != null
        ? LatLng(widget.filterCenter!.latitude, widget.filterCenter!.longitude)
        : null;
    _filterRadius = widget.filterRadius ?? 5000;
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    setState(() {
      isLoading = true;
    });

    try {
      var snapshot = await _firestore.collection('devices').get();
      _devices = snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint("Error fetching devices: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _centerMap() {
    if (_locationFilterEnabled && _filterCenter != null) {
      double zoomLevel = _calculateZoomForRadius(_filterRadius);
      _mapController.move(_filterCenter!, zoomLevel);
    } else {
      _centerMapOnDevices();
    }
  }

  void _centerMapOnDevices() {
    List<LatLng> validLocations = [];

    for (var device in _devices) {
      if (device['location'] != null && device['location'] is GeoPoint) {
        GeoPoint geoPoint = device['location'];
        validLocations.add(LatLng(geoPoint.latitude, geoPoint.longitude));
      }
    }

    if (validLocations.isEmpty) {
      _mapController.move(_defaultCenter, 9.0);
      return;
    }

    if (validLocations.length == 1) {
      _mapController.move(validLocations.first, 13.0);
      return;
    }

    double minLat = validLocations.first.latitude;
    double maxLat = validLocations.first.latitude;
    double minLng = validLocations.first.longitude;
    double maxLng = validLocations.first.longitude;

    for (var point in validLocations) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final distance = calculateDistance(minLat, minLng, maxLat, maxLng);
    final zoom = calculateZoomLevel(distance);

    _mapController.move(center, zoom);
  }

  double _calculateZoomForRadius(double radiusInMeters) {
    const worldCircumference = 40075016.686;
    const tileSize = 256;
    const screenSizePx = 400.0; // Approx device screen size

    double adjustedRadius = radiusInMeters * 1.2;
    double metersPerPixel = (adjustedRadius * 2) / screenSizePx;
    double zoomLevel = log(worldCircumference / (metersPerPixel * tileSize)) / log(2);

    return zoomLevel.clamp(1.0, 18.0);
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distanceInMeters / 1000;
  }

  double calculateZoomLevel(double distanceInKm) {
    const double zoomScaleFactor = 10.0;
    double zoom = log(zoomScaleFactor / distanceInKm) / log(2);
    return zoom.clamp(1.0, 18.0);
  }

  void _openRadiusSlider() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Adjust Radius: ${(_filterRadius / 1000).toStringAsFixed(0)} km',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _filterRadius,
                    min: 5000,
                    max: 50000,
                    divisions: 9,
                    label: '${(_filterRadius / 1000).round()} km',
                    onChanged: (value) {
                      setStateSheet(() {
                        _filterRadius = value;
                      });
                      setState(() {
                        _filterRadius = value;
                      });
                      _centerMap();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Marker> _generateMarkers() {
    List<Marker> markers = [];

    for (var device in _devices) {
      if (device['location'] != null && device['location'] is GeoPoint) {
        GeoPoint geoPoint = device['location'];

        if (_locationFilterEnabled && _filterCenter != null) {
          double distance = Geolocator.distanceBetween(
            geoPoint.latitude,
            geoPoint.longitude,
            _filterCenter!.latitude,
            _filterCenter!.longitude,
          );
          if (distance > _filterRadius) continue;
        }

        markers.add(
          Marker(
            width: 120.0,
            height: 70,
            point: LatLng(geoPoint.latitude, geoPoint.longitude),
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/device-details',
                  arguments: device['id'],
                );
              },
              child: Column(
                children: [
                  const Icon(Icons.location_on, color: Colors.green, size: 40),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
                      ],
                    ),
                    child: Text(
                      device['name'] ?? 'Unknown',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices on the Map', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(
              _locationFilterEnabled ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
            ),
            tooltip: 'Toggle Location Filter',
            onPressed: () {
              setState(() {
                _locationFilterEnabled = !_locationFilterEnabled;
                if (_locationFilterEnabled && _filterCenter == null) {
                  _filterCenter = _defaultCenter;
                }
              });
              _centerMap();
            },
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong, color: Colors.white),
            onPressed: _centerMap,
            tooltip: 'Center Map',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 9.0,
                onMapReady: _centerMap,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                if (_locationFilterEnabled && _filterCenter != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _filterCenter!,
                        color: Colors.red,
                        borderStrokeWidth: 2,
                        borderColor: Colors.red,
                        useRadiusInMeter: true,
                        radius: _filterRadius,
                      ),
                    ],
                  ),
                MarkerLayer(markers: _generateMarkers()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepOrange,
        onPressed: _locationFilterEnabled ? _openRadiusSlider : _fetchDevices,
        tooltip: _locationFilterEnabled ? 'Adjust Radius' : 'Refresh Map',
        child: Icon(_locationFilterEnabled ? Icons.tune : Icons.refresh),
      ),
    );
  }
}
