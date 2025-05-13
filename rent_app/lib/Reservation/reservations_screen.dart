import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _currentView = 'received'; // 'received' or 'made'

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser!;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations'),
        backgroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          _buildToggleButtons(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getReservationsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      _currentView == 'received'
                          ? 'Je hebt nog geen ontvangen reservaties.'
                          : 'Je hebt nog geen reservaties geplaatst.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final reservations = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    final reservation = reservations[index].data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.devices,
                            color: Colors.green.shade200,
                          ),
                        ),
                        title: Text(
                          reservation['deviceName'] ?? 'Onbekend apparaat',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Van ${_formatDate(reservation['startDate'])} tot ${_formatDate(reservation['endDate'])}',
                            ),
                            if (reservation['totalPrice'] != null)
                              Text(
                                'Totaal: €${reservation['totalPrice'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (_currentView == 'received')
                              Text(
                                'Gehuurd door: ${reservation['renterEmail'] ?? 'Onbekend'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(reservation['status']),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getStatusText(reservation['status']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () {
                          // Navigate to device detail or reservation detail
                          Navigator.pushNamed(
                            context,
                            '/device-details',
                            arguments: reservation['deviceId'],
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getReservationsStream(String userId) {
    if (_currentView == 'received') {
      // Reservations for devices I own
      return _firestore
          .collection('reservations')
          .where('ownerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      // Reservations I've made
      return _firestore
          .collection('reservations')
          .where('renterId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  Widget _buildToggleButtons() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
<<<<<<< HEAD
          _buildToggleButton('My reservations', 'received'),
          const SizedBox(width: 8),
          _buildToggleButton('My bookings', 'made'),
=======
          _buildToggleButton('Ontvangen', 'received'),
          const SizedBox(width: 8),
          _buildToggleButton('Geplaatst', 'made'),
>>>>>>> bb851fc (changed theme and tested reservations with firebase)
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, String viewKey) {
    final isSelected = _currentView == viewKey;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _currentView = viewKey;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.green : Colors.grey.shade300,
          foregroundColor: isSelected ? Colors.white : Colors.black87,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}/${date.month}/${date.year}";
    }
    return 'Onbekend';
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'In afwachting';
      case 'confirmed':
        return 'Bevestigd';
      case 'cancelled':
        return 'Geannuleerd';
      default:
        return 'Onbekend';
    }
  }
}