import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'In attesa';
      case 'accepted':
        return 'Accettato';
      case 'delivering':
        return 'In consegna';
      case 'completed':
        return 'Completato';
      case 'cancelled':
        return 'Annullato';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'delivering':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final accentDark = const Color(0xFF7A3E2B);

    if (user == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('I miei ordini'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: accentDark,
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
            child: Center(child: Text('Devi essere loggato')),
          ),
        ),
      );
    }

    final q = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('I miei ordini'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: accentDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF9F5F1), Color(0xFFEDE1D7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Errore: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text('Nessun ordine ancora 🍸'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data();

                  final status = (data['status'] ?? 'pending').toString();
                  final total = (data['total'] as num?)?.toDouble() ?? 0.0;
                  final payment = (data['paymentMethod'] ?? '').toString();
                  final riderName = (data['assignedRiderName'] ?? '').toString();
                  final riderId = (data['assignedRiderId'] ?? '').toString();

                  final items = (data['items'] as List?) ?? [];
                  final itemsCount = items.fold<int>(0, (s, e) {
                    final m = (e as Map?)?.cast<String, dynamic>() ?? {};
                    final qty = (m['qty'] as num?)?.toInt() ?? 0;
                    return s + qty;
                  });

                  final createdAt = (data['createdAt'] as Timestamp?);
                  final dateStr = createdAt == null ? '—' : _formatDate(createdAt.toDate());

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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Data: $dateStr'),
                        const SizedBox(height: 4),
                        Text('Articoli: $itemsCount'),
                        const SizedBox(height: 4),
                        Text('Pagamento: ${payment == 'cash' ? 'Contanti' : 'Carta'}'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Totale',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              '€${total.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        if (riderName.isNotEmpty || riderId.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text('Rider: ${riderName.isEmpty ? riderId : riderName}'),
                          _LiveLocationTile(userId: riderId),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _LiveLocationTile extends StatelessWidget {
  final String userId;

  const _LiveLocationTile({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return const Text('Posizione rider: —');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('live_locations')
          .doc(userId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Text('Posizione rider: —');
        }

        final data = snap.data!.data();
        if (data == null) {
          return const Text('Posizione rider: —');
        }

        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        final updatedAt = data['updatedAt'] as Timestamp?;
        final timeStr = updatedAt == null
            ? '—'
            : '${updatedAt.toDate().hour.toString().padLeft(2, '0')}:${updatedAt.toDate().minute.toString().padLeft(2, '0')}';

        if (lat == null || lng == null) {
          return const Text('Posizione rider: —');
        }

        return Text(
          'Posizione rider: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)} (agg. $timeStr)',
        );
      },
    );
  }
}
