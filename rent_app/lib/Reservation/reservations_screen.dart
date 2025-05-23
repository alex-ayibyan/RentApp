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

  String _currentView = 'received';
  Set<String> _removedReservationIds = {};

  Future<void> _updateReservationStatus(
    String reservationId,
    String newStatus,
  ) async {
    try {
      final reservationRef = _firestore
          .collection('reservations')
          .doc(reservationId);

      if (newStatus == 'cancelled') {
        await reservationRef.update({
          'status': 'cancelled',
          'startDate': null,
          'endDate': null,
        });
      } else {
        // Alleen status bijwerken (bijv. naar "confirmed")
        await reservationRef.update({'status': newStatus});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'cancelled'
                ? 'Reservatie geweigerd.'
                : 'Reservatie bevestigd.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fout bij bijwerken: $e')));
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Niet beschikbaar';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}/${date.month}/${date.year}";
    }
    return 'Onbekend';
  }

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
              stream: _getReservationsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
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

                final reservations =
                    snapshot.data!.docs
                        .where(
                          (doc) => !_removedReservationIds.contains(doc.id),
                        )
                        .toList();

                return ListView.builder(
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    final reservation =
                        reservations[index].data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                            if (_currentView == 'received' &&
                                reservation['status'] == 'pending')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                      tooltip: 'Accepteren',
                                      onPressed: () {
                                        _updateReservationStatus(
                                          reservations[index].id,
                                          'confirmed',
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.block,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Weigeren',
                                      onPressed: () {
                                        _updateReservationStatus(
                                          reservations[index].id,
                                          'cancelled',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            if (_currentView == 'received' &&
                                (reservation['status'] == 'confirmed' ||
                                    reservation['status'] == 'cancelled'))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _removedReservationIds.add(
                                        reservations[index].id,
                                      );
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Verwijder uit lijst',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
          _buildToggleButton('Ontvangen', 'received'),
          const SizedBox(width: 8),
          _buildToggleButton('Geplaatst', 'made'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label),
      ),
    );
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
        return 'Geweigerd';
      default:
        return 'Onbekend';
    }
  }
}
