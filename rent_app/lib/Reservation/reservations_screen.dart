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

  String _currentView = 'received'; // 'received' of 'made'

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn Reservaties'),
        backgroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          _buildToggleButtons(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('reservations').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allReservations = snapshot.data!.docs;

                final filtered = allReservations.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _currentView == 'received'
                      ? data['ownerId'] == user.uid
                      : data['renterId'] == user.uid;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _currentView == 'received'
                          ? 'Je hebt nog geen ontvangen reservaties.'
                          : 'Je hebt nog geen reservaties geplaatst.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final reservation = filtered[index].data() as Map<String, dynamic>;
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore
                          .collection('devices')
                          .doc(reservation['deviceId'])
                          .get(),
                      builder: (context, deviceSnapshot) {
                        if (!deviceSnapshot.hasData) {
                          return const ListTile(title: Text("Device wordt geladen..."));
                        }

                        final device = deviceSnapshot.data!.data() as Map<String, dynamic>?;

                        return ListTile(
                          leading: Icon(Icons.devices, color: Colors.deepOrangeAccent.shade200),
                          title: Text(device?['name'] ?? 'Onbekend apparaat'),
                          subtitle: Text(
                            'Van ${_formatDate(reservation['startDate'])} tot ${_formatDate(reservation['endDate'])}',
                          ),
                          trailing: Text(
                            reservation['status'] ?? 'pending',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
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

  Widget _buildToggleButtons() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildToggleButton('Mijn reservaties', 'received'),
          const SizedBox(width: 8),
          _buildToggleButton('Mijn reserveringen', 'made'),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, String viewKey) {
    final isSelected = _currentView == viewKey;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _currentView = viewKey;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.deepOrangeAccent : Colors.grey.shade300,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
      ),
      child: Text(label),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}/${date.month}/${date.year}";
    }
    return 'Onbekend';
  }
}
