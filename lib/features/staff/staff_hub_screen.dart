import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/app_snackbar.dart';

class StaffHubScreen extends StatefulWidget {
  const StaffHubScreen({super.key});

  @override
  State<StaffHubScreen> createState() => _StaffHubScreenState();
}

class _StaffHubScreenState extends State<StaffHubScreen> {
  @override
  Widget build(BuildContext context) {
    final accentDark = const Color(0xFF7A3E2B);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Area staff'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: accentDark,
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () => context.go('/'),
            ),
          ],
          bottom: TabBar(
            labelColor: accentDark,
            tabs: const [
              Tab(text: 'Staff'),
              Tab(text: 'Rider'),
              Tab(text: 'Proprietario'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF9F5F1), Color(0xFFEDE1D7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const SafeArea(
            child: TabBarView(
              children: [
                _StaffOrdersTab(),
                _RiderOrdersTab(),
                _OwnerPanelTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffOrdersTab extends StatefulWidget {
  const _StaffOrdersTab();

  @override
  State<_StaffOrdersTab> createState() => _StaffOrdersTabState();
}

class _StaffOrdersTabState extends State<_StaffOrdersTab> {
  final Map<String, String?> _assignedRider = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> _ridersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'rider')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('status', whereIn: ['pending', 'accepted', 'delivering'])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _updateStatus(String orderId, String status) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': status,
    });
  }

  Future<void> _assignRider(
    String orderId,
    String riderId,
    String riderName,
  ) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'assignedRiderId': riderId,
      'assignedRiderName': riderName,
      'status': 'accepted',
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ridersStream(),
      builder: (context, ridersSnap) {
        if (!ridersSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final riders = ridersSnap.data!.docs.map((doc) {
          final data = doc.data();
          final first = (data['firstName'] ?? '').toString();
          final last = (data['lastName'] ?? '').toString();
          final name = '$first $last'.trim();
          return {
            'id': doc.id,
            'name': name.isEmpty ? 'Rider ${doc.id.substring(0, 4)}' : name,
          };
        }).toList();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _ordersStream(),
          builder: (context, ordersSnap) {
            if (!ordersSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = ordersSnap.data!.docs;

            if (orders.isEmpty) {
              return const Center(child: Text('Nessun ordine da gestire.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = orders[index];
                final data = doc.data();
                final status = (data['status'] ?? 'pending').toString();
                final customer = (data['customerName'] ?? 'Cliente').toString();
                final phone = (data['customerPhone'] ?? '').toString();
                final total = (data['total'] as num?)?.toDouble() ?? 0.0;
                final assignedName = (data['assignedRiderName'] ?? '').toString();

                final selected = _assignedRider[doc.id] ??
                    (data['assignedRiderId'] as String?);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ordine #${doc.id.substring(0, 6).toUpperCase()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            status.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Cliente: $customer'),
                      Text('Telefono: ${phone.isEmpty ? '—' : phone}'),
                      const SizedBox(height: 8),
                      Text('Totale: €${total.toStringAsFixed(2)}'),
                      if (assignedName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Rider assegnato: $assignedName'),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: status == 'pending'
                                ? () => _updateStatus(doc.id, 'accepted')
                                : null,
                            child: const Text('Accetta'),
                          ),
                          OutlinedButton(
                            onPressed: status == 'pending' || status == 'accepted'
                                ? () => _updateStatus(doc.id, 'cancelled')
                                : null,
                            child: const Text('Rifiuta'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selected,
                              hint: const Text('Assegna un rider'),
                              items: riders
                                  .map((r) => DropdownMenuItem<String>(
                                        value: r['id'],
                                        child: Text(r['name'] as String),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _assignedRider[doc.id] = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: selected == null
                                ? null
                                : () {
                                    final rider = riders.firstWhere(
                                      (r) => r['id'] == selected,
                                    );
                                    _assignRider(
                                      doc.id,
                                      rider['id'] as String,
                                      rider['name'] as String,
                                    );
                                  },
                            child: const Text('Assegna'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RiderOrdersTab extends StatefulWidget {
  const _RiderOrdersTab();

  @override
  State<_RiderOrdersTab> createState() => _RiderOrdersTabState();
}

class _RiderOrdersTabState extends State<_RiderOrdersTab> {
  StreamSubscription<Position>? _posSub;
  bool _sharing = false;

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleSharing(bool value) async {
    if (value) {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          AppSnackBar.show(
            context,
            'GPS non disponibile',
            type: AppSnackBarType.error,
          );
        }
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          AppSnackBar.show(
            context,
            'Permesso posizione negato',
            type: AppSnackBarType.error,
          );
        }
        return;
      }

      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((p) => _updateLiveLocation(p));

      setState(() => _sharing = true);
    } else {
      await _posSub?.cancel();
      setState(() => _sharing = false);
    }
  }

  Future<void> _updateLiveLocation(Position p) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('live_locations').doc(user.uid).set(
      {
        'userId': user.uid,
        'role': 'rider',
        'lat': p.latitude,
        'lng': p.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream(String riderId) {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('assignedRiderId', isEqualTo: riderId)
        .where('status', whereIn: ['accepted', 'delivering'])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _updateStatus(String orderId, String status) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': status,
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Devi essere loggato.'));
    }

    return Column(
      children: [
        SwitchListTile(
          title: const Text('Condividi posizione in tempo reale'),
          subtitle: const Text('I clienti vedranno la tua posizione mentre consegni.'),
          value: _sharing,
          onChanged: _toggleSharing,
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _ordersStream(user.uid),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final orders = snap.data!.docs;
              if (orders.isEmpty) {
                return const Center(child: Text('Nessun ordine assegnato.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = orders[index];
                  final data = doc.data();
                  final customer = (data['customerName'] ?? 'Cliente').toString();
                  final phone = (data['customerPhone'] ?? '').toString();
                  final status = (data['status'] ?? '').toString();
                  final total = (data['total'] as num?)?.toDouble() ?? 0.0;
                  final location = data['customerLocation'] as GeoPoint?;
                  final customerId = (data['userId'] ?? '').toString();

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ordine #${doc.id.substring(0, 6).toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text('Cliente: $customer'),
                        Text('Telefono: ${phone.isEmpty ? '—' : phone}'),
                        const SizedBox(height: 8),
                        Text('Totale: €${total.toStringAsFixed(2)}'),
                        const SizedBox(height: 8),
                        if (location != null)
                          Text(
                            'Posizione cliente: ${location.latitude.toStringAsFixed(5)}, '
                            '${location.longitude.toStringAsFixed(5)}',
                          )
                        else
                          const Text('Posizione cliente: —'),
                        const SizedBox(height: 8),
                        _LiveLocationTile(userId: customerId),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: status == 'accepted'
                                  ? () => _updateStatus(doc.id, 'delivering')
                                  : null,
                              child: const Text('Avvia consegna'),
                            ),
                            ElevatedButton(
                              onPressed: status != 'completed'
                                  ? () => _updateStatus(doc.id, 'completed')
                                  : null,
                              child: const Text('Consegna completata'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OwnerPanelTab extends StatefulWidget {
  const _OwnerPanelTab();

  @override
  State<_OwnerPanelTab> createState() => _OwnerPanelTabState();
}

class _OwnerPanelTabState extends State<_OwnerPanelTab> {
  final _userIdController = TextEditingController();
  String _role = 'staff';

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _cocktailsStream() {
    return FirebaseFirestore.instance.collection('cocktails').orderBy('sort').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _teamStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['staff', 'rider'])
        .snapshots();
  }

  Future<void> _updateUserRole(String uid, String role) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'role': role,
    });
  }

  Future<void> _addCocktailDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final categoryController = TextEditingController();
    final baseLabelController = TextEditingController(text: 'Base');
    final basePriceController = TextEditingController();
    final premiumLabelController = TextEditingController(text: 'Premium');
    final premiumPriceController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuovo cocktail'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Descrizione'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: baseLabelController,
                  decoration: const InputDecoration(labelText: 'Variante base'),
                ),
                TextField(
                  controller: basePriceController,
                  decoration: const InputDecoration(labelText: 'Prezzo base'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: premiumLabelController,
                  decoration: const InputDecoration(labelText: 'Variante premium'),
                ),
                TextField(
                  controller: premiumPriceController,
                  decoration: const InputDecoration(labelText: 'Prezzo premium'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final basePrice = double.tryParse(basePriceController.text) ?? 0.0;
    final premiumPrice = double.tryParse(premiumPriceController.text) ?? 0.0;

    await FirebaseFirestore.instance.collection('cocktails').add({
      'name': nameController.text.trim(),
      'category': categoryController.text.trim(),
      'description': descController.text.trim(),
      'isActive': true,
      'sort': DateTime.now().millisecondsSinceEpoch,
      'variants': {
        'base': {
          'label': baseLabelController.text.trim(),
          'price': basePrice,
        },
        'premium': {
          'label': premiumLabelController.text.trim(),
          'price': premiumPrice,
        },
      },
    });
  }

  Future<void> _editVariantsDialog(
    String docId,
    Map<String, dynamic> variants,
  ) async {
    final entries = variants.entries.toList();
    final labelControllers = <String, TextEditingController>{};
    final priceControllers = <String, TextEditingController>{};

    for (final entry in entries) {
      final data = (entry.value as Map?)?.cast<String, dynamic>() ?? {};
      labelControllers[entry.key] =
          TextEditingController(text: (data['label'] ?? entry.key).toString());
      priceControllers[entry.key] =
          TextEditingController(text: (data['price'] ?? '').toString());
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifica varianti'),
          content: SingleChildScrollView(
            child: Column(
              children: entries.map((entry) {
                final key = entry.key;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextField(
                      controller: labelControllers[key],
                      decoration: const InputDecoration(labelText: 'Etichetta'),
                    ),
                    TextField(
                      controller: priceControllers[key],
                      decoration: const InputDecoration(labelText: 'Prezzo'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final updated = <String, dynamic>{};
    for (final entry in entries) {
      final key = entry.key;
      final label = labelControllers[key]?.text.trim() ?? key;
      final price = double.tryParse(priceControllers[key]?.text ?? '') ?? 0.0;
      updated[key] = {
        'label': label,
        'price': price,
      };
    }

    await FirebaseFirestore.instance.collection('cocktails').doc(docId).update({
      'variants': updated,
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Gestione ordini e risorse',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          title: const Text('Cocktail e prezzi'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _addCocktailDialog,
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi cocktail'),
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _cocktailsStream(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final cocktails = snap.data!.docs;
                if (cocktails.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Nessun cocktail presente.'),
                  );
                }

                return Column(
                  children: cocktails.map((doc) {
                    final data = doc.data();
                    final name = (data['name'] ?? '').toString();
                    final category = (data['category'] ?? '').toString();
                    final isActive = (data['isActive'] as bool?) ?? true;
                    final variants =
                        (data['variants'] as Map?)?.cast<String, dynamic>() ?? {};

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            if (category.isNotEmpty)
                              Text('Categoria: $category'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Attivo'),
                                Switch(
                                  value: isActive,
                                  onChanged: (value) {
                                    FirebaseFirestore.instance
                                        .collection('cocktails')
                                        .doc(doc.id)
                                        .update({'isActive': value});
                                  },
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton(
                                onPressed: variants.isEmpty
                                    ? null
                                    : () => _editVariantsDialog(doc.id, variants),
                                child: const Text('Modifica varianti'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text('Staff e rider'),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userIdController,
                    decoration: const InputDecoration(
                      labelText: 'UID utente',
                      hintText: 'Inserisci UID',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    DropdownMenuItem(value: 'rider', child: Text('Rider')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _role = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: () async {
                  final uid = _userIdController.text.trim();
                  if (uid.isEmpty) return;
                  await _updateUserRole(uid, _role);
                  if (mounted) {
                    AppSnackBar.show(
                      context,
                      'Ruolo aggiornato',
                      type: AppSnackBarType.success,
                    );
                  }
                },
                child: const Text('Aggiungi / aggiorna'),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _teamStream(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final team = snap.data!.docs;
                if (team.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Nessun membro staff/rider.'),
                  );
                }

                return Column(
                  children: team.map((doc) {
                    final data = doc.data();
                    final first = (data['firstName'] ?? '').toString();
                    final last = (data['lastName'] ?? '').toString();
                    final role = (data['role'] ?? '').toString();
                    final name = '$first $last'.trim();
                    return ListTile(
                      title: Text(name.isEmpty ? doc.id : name),
                      subtitle: Text('Ruolo: $role'),
                      trailing: TextButton(
                        onPressed: () => _updateUserRole(doc.id, 'customer'),
                        child: const Text('Rimuovi'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _LiveLocationTile extends StatelessWidget {
  final String userId;

  const _LiveLocationTile({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return const Text('Posizione live: —');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('live_locations')
          .doc(userId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Text('Posizione live: —');
        }

        final data = snap.data!.data();
        if (data == null) {
          return const Text('Posizione live: —');
        }

        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        final updatedAt = data['updatedAt'] as Timestamp?;
        final timeStr = updatedAt == null
            ? '—'
            : '${updatedAt.toDate().hour.toString().padLeft(2, '0')}:${updatedAt.toDate().minute.toString().padLeft(2, '0')}';

        if (lat == null || lng == null) {
          return const Text('Posizione live: —');
        }

        return Text(
          'Posizione live: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)} (agg. $timeStr)',
        );
      },
    );
  }
}
