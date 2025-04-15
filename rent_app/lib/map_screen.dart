import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceMapScreen extends StatefulWidget {
  const DeviceMapScreen({super.key});

  @override
  DeviceMapScreenState createState() => DeviceMapScreenState();
}

class DeviceMapScreenState extends State<DeviceMapScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _devices = [];
  bool isLoading = true;
  final MapController _mapController = MapController();

  final LatLng _defaultCenter = LatLng(51.2297, 4.4180); //ap

  @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      _fetchDevices(); // refresh screen
    }

  Future<void> _fetchDevices() async {
    setState(() {
      isLoading = true;
    });

    try {
      var snapshot = await _firestore.collection('devices').get();

      setState(() {
        _devices = snapshot.docs.map((doc) {
          var data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fout bij ophalen toestellen: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _centerMapOnDevices() {
    List<LatLng> validLocations = _devices
        .where((device) => device['location'] != null)
        .map((device) => LatLng(
              device['location']['latitude'],
              device['location']['longitude'],
            ))
        .toList();

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
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    final distance = calculateDistance(minLat, minLng, maxLat, maxLng);
    final zoom = calculateZoomLevel(distance);

    _mapController.move(center, zoom);
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    double distanceInKilometers = distanceInMeters / 1000;
    
    return distanceInKilometers;
  }

  double calculateDistanceEquirectangular(double lat1, double lon1, double lat2, double lon2) {
    final Distance distance = Distance();
    final LatLng point1 = LatLng(lat1, lon1);
    final LatLng point2 = LatLng(lat2, lon2);
    final double kilometers = distance.distance(point1, point2) / 1000;

    return kilometers;
  }

  double calculateZoomLevel(double distanceInKm) {
    const double zoomScaleFactor = 10.0;
    double zoom = log(zoomScaleFactor/distanceInKm) / log(2);

    return zoom.clamp(1.0, 18.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Apparaten op de Kaart', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(Icons.center_focus_strong, color: Colors.white),
            onPressed: _centerMapOnDevices,
            tooltip: 'Centreer kaart op apparaten',
          ),
        ],
      ),
      body: isLoading
        ? Center(child: CircularProgressIndicator())
        : RefreshIndicator(
      onRefresh: () async {
        await _fetchDevices();
      },
      child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 9.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: _generateMarkers(),
              ),
            ],
          ),
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _fetchDevices().then((_) => _centerMapOnDevices());
        },
        backgroundColor: Colors.deepOrangeAccent,
        tooltip: 'Ververs kaart',
        child: Icon(Icons.refresh),
      ),
    );
  }

  List<Marker> _generateMarkers() {
    List<Marker> markers = [];

    for (var device in _devices) {
      if (device['location'] != null &&
          device['location']['latitude'] != null &&
          device['location']['longitude'] != null) {

        markers.add(
          Marker(
            width: 120.0,
            height: 70,
            point: LatLng(
              device['location']['latitude'],
              device['location']['longitude'],
            ),
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
                  Icon(
                    Icons.location_on,
                    color: Colors.deepOrangeAccent,
                    size: 40,
                  ),
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      device['name'] ?? 'Onbekend',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
        );
      } else {
        debugPrint("Device ${device['name']} has no location data");
      }
    }

    return markers;
  }
}