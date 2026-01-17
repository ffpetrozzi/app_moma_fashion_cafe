import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/app_snackbar.dart';
class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  StreamSubscription<Position>? _posSub;
  Position? _pos;
  bool _locDenied = false;

  // Coordinate Moma Fashion Cafè (placeholder).
  // Se vuoi, mettiamo quelle precise del locale.
  static const double _shopLat = 41.7189;
  static const double _shopLng = 13.6150;

  @override
  void initState() {
    super.initState();
    _startLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  void _openAccountSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Il mio profilo'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/profile');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('I miei ordini'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/orders');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    context.go('/'); // AuthGate ti rimanda al login
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _locDenied = true);
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _locDenied = true);
        return;
      }

      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((p) {
        if (!mounted) return;
        setState(() => _pos = p);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locDenied = true);
    }
  }

  double _distanceMeters(Position? p) {
    if (p == null) return double.infinity;
    return Geolocator.distanceBetween(p.latitude, p.longitude, _shopLat, _shopLng);
  }

  String _todayKey() {
    switch (DateTime.now().weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      default:
        return 'mon';
    }
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _timeOnDate(DateTime date, int hh, int mm) =>
      DateTime(date.year, date.month, date.day, hh, mm);

  List<DateTime>? _parseRangeOnDate(DateTime date, String range) {
    // range: "08:00-02:00"
    final parts = range.split('-');
    if (parts.length != 2) return null;

    int? parseH(String s) => int.tryParse(s.trim().split(':').first);
    int? parseM(String s) => int.tryParse(s.trim().split(':').last);

    final a = parts[0].trim();
    final b = parts[1].trim();

    final aParts = a.split(':');
    final bParts = b.split(':');
    if (aParts.length != 2 || bParts.length != 2) return null;

    final sh = int.tryParse(aParts[0]);
    final sm = int.tryParse(aParts[1]);
    final eh = int.tryParse(bParts[0]);
    final em = int.tryParse(bParts[1]);
    if (sh == null || sm == null || eh == null || em == null) return null;

    final start = _timeOnDate(date, sh, sm);
    var end = _timeOnDate(date, eh, em);

    // Se chiude dopo mezzanotte (end <= start), end è il giorno dopo
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    return [start, end];
  }

  String _keyFromWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      default:
        return 'mon';
    }
  }

  bool _isOpenFromHours(Map<String, dynamic> hours) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayKey = _keyFromWeekday(now.weekday);
    final yesterdayKey = _keyFromWeekday(now.subtract(const Duration(days: 1)).weekday);

    final todayStr = (hours[todayKey] ?? 'Chiuso').toString();
    final yStr = (hours[yesterdayKey] ?? 'Chiuso').toString();

    // 1) Controllo fascia di oggi
    if (todayStr.toLowerCase() != 'chiuso') {
      final r = _parseRangeOnDate(today, todayStr);
      if (r != null) {
        final start = r[0], end = r[1];
        if (now.isAfter(start) && now.isBefore(end)) return true;
      }
    }

    // 2) Controllo fascia di ieri che sfora oltre mezzanotte (es. 08:00-03:00)
    if (yStr.toLowerCase() != 'chiuso') {
      final r = _parseRangeOnDate(yesterday, yStr);
      if (r != null) {
        final start = r[0], end = r[1];
        // Se sfora (end è oggi o oltre) e now è dentro
        if (now.isAfter(start) && now.isBefore(end)) return true;
      }
    }

    return false;
  }

  bool _isNowOpen(Map<String, dynamic> store) {
    final hours = (store['hours'] as Map?)?.cast<String, dynamic>() ?? {};
    return _isOpenFromHours(hours);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final accent = const Color(0xFFB5654B);
    final accentDark = const Color(0xFF7A3E2B);
    final cream = const Color(0xFFF7F2EC);

    final userDoc = uid == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(uid);

    // Cambia qui se il tuo doc store è diverso:
    final storeDoc = FirebaseFirestore.instance.collection('settings').doc('store');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Moma Fashion Cafè'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: accentDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _openAccountSheet,
            tooltip: 'Account',
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
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: storeDoc.snapshots(),
            builder: (context, storeSnap) {
              if (storeSnap.hasError) {
                return const Center(child: Text('Errore caricamento store'));
              }
              if (!storeSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final store = storeSnap.data!.data() ?? <String, dynamic>{};
              final isOpen = _isNowOpen(store);

              final hours = (store['hours'] as Map?)?.cast<String, dynamic>() ?? {};
              final todayKey = _todayKey();
              final todayHours = (hours[todayKey] ?? 'Chiuso').toString();

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: userDoc?.snapshots(),
                builder: (context, userSnap) {
                  final u = userSnap.data?.data() ?? <String, dynamic>{};

                  final firstName = (u['firstName'] ?? '').toString().trim();
                  final lastName = (u['lastName'] ?? '').toString().trim();
                  final phone = (u['phone'] ?? '').toString().trim();
                  final phoneVerified = (u['phoneVerified'] as bool?) ?? false;

                  final profileComplete =
                      firstName.isNotEmpty && lastName.isNotEmpty && phone.isNotEmpty && phoneVerified;

                  final dist = _distanceMeters(_pos);
                  final insideRadius = dist <= 200;

                  final canOrderNow = isOpen && insideRadius && profileComplete;

                  return RefreshIndicator(
                    color: accent,
                    onRefresh: () async {
                      await Future<void>.delayed(const Duration(milliseconds: 300));
                      if (!mounted) return;
                      setState(() {});
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        Text(
                          firstName.isEmpty ? 'Benvenuto 👋' : 'Bentornato, $firstName 👋',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: accentDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'La tua pausa premium, servita con stile.',
                          style: TextStyle(color: accentDark.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E1E1E), Color(0xFF3A2417)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.local_bar, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Moma Fashion Cafè',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Cocktail & coffee experience',
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _pill(text: isOpen ? 'APERTO' : 'CHIUSO', ok: isOpen),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _infoChip(
                                    icon: Icons.schedule,
                                    label: 'Oggi: $todayHours',
                                  ),
                                  const SizedBox(width: 10),
                                  _infoChip(
                                    icon: Icons.delivery_dining,
                                    label: 'Delivery 200m',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _sectionTitle('Azioni rapide'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _actionCard(
                              title: 'Ordina ora',
                              subtitle: isOpen ? 'Menu digitale' : 'Apriamo presto',
                              icon: Icons.shopping_bag,
                              color: accent,
                              onTap: canOrderNow ? () => context.push('/menu') : null,
                            ),
                            _actionCard(
                              title: 'Profilo',
                              subtitle: profileComplete ? 'Completo' : 'Completa dati',
                              icon: Icons.person,
                              color: accentDark,
                              onTap: () => context.push('/profile'),
                            ),
                            _actionCard(
                              title: 'I miei ordini',
                              subtitle: 'Storico & stato',
                              icon: Icons.receipt_long,
                              color: const Color(0xFF5C4B3B),
                              onTap: () => context.push('/orders'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _card(
                          title: 'Profilo',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _kv('Nome', firstName.isEmpty ? '—' : '$firstName $lastName'),
                              const SizedBox(height: 6),
                              _kv('Telefono', phone.isEmpty ? '—' : phone),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    phoneVerified ? Icons.verified : Icons.error_outline,
                                    size: 18,
                                    color: phoneVerified ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    phoneVerified ? 'Telefono verificato' : 'Telefono da verificare',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: phoneVerified ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              if (!profileComplete) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => context.push('/profile'),
                                    child: const Text('Completa profilo'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _card(
                          title: 'La tua posizione',
                          child: _locDenied
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Permesso di localizzazione negato o servizi disattivati.',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: _startLocation,
                                        child: const Text('Riprova'),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dist.isInfinite
                                          ? 'Posizione non disponibile (attendo GPS...)'
                                          : 'Sei a ${dist.toStringAsFixed(0)}m dal locale',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          insideRadius ? Icons.check_circle : Icons.cancel,
                                          color: insideRadius ? Colors.green : Colors.red,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            insideRadius
                                                ? 'Puoi ordinare, ti trovi nel raggio di 200m'
                                                : 'Non puoi ordinare, devi essere a massimo 200m',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: insideRadius ? Colors.green : Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),
                        _card(
                          title: 'Orari',
                          child: Column(
                            children: [
                              _hoursRow('Lun', (hours['mon'] ?? 'Chiuso').toString()),
                              _hoursRow('Mar', (hours['tue'] ?? 'Chiuso').toString()),
                              _hoursRow('Mer', (hours['wed'] ?? 'Chiuso').toString()),
                              _hoursRow('Gio', (hours['thu'] ?? 'Chiuso').toString()),
                              _hoursRow('Ven', (hours['fri'] ?? 'Chiuso').toString()),
                              _hoursRow('Sab', (hours['sat'] ?? 'Chiuso').toString()),
                              _hoursRow('Dom', (hours['sun'] ?? 'Chiuso').toString()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: cream,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: canOrderNow
                                ? () => context.push('/menu')
                                : () {
                                    if (!profileComplete) {
                                      AppSnackBar.show(
                                        context,
                                        'Completa il profilo (nome, cognome, telefono verificato) per ordinare.',
                                        type: AppSnackBarType.info,
                                      );
                                      context.push('/profile');
                                    }
                                  },
                            child: Text(
                              !isOpen
                                  ? 'Locale chiuso'
                                  : (!profileComplete
                                      ? 'Completa profilo per ordinare'
                                      : (insideRadius ? 'Ordina ora' : 'Fuori dal raggio')),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            'Copyright ©2026 Moma Fashion Cafè by Filippo Petrozzi',
                            style: TextStyle(color: accentDark.withOpacity(0.5)),
                          ),
                        ),
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

  Widget _card({String? title, required Widget child}) {
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
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                child,
              ],
            ),
    );
  }

  Widget _pill({required String text, required bool ok}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ok ? Colors.green.withOpacity(0.18) : Colors.red.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: ok ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  Widget _infoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: Color(0xFF6B3F2B),
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 160,
      child: Material(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(k, style: const TextStyle(color: Colors.black54))),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800))),
      ],
    );
  }

  Widget _hoursRow(String day, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(day, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}
