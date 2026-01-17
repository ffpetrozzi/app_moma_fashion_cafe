import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_profile.dart';
import '../../core/services/firestore_service.dart';
import '../home/customer_home.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  int _refresh = 0;
  bool _creatingProfile = false;
  String? _profileError;

  @override
  Widget build(BuildContext context) {
    final _ = _refresh;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;

        // -----------------------
        // NON LOGGATO
        // -----------------------
        if (user == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Moma Fashion Cafè',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ordina cocktail e ricevili a domicilio entro 200m.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Accedi'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Registrati'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final emailVerified = user.emailVerified;
        final phoneVerified = user.phoneNumber != null;

        // -----------------------
        // EMAIL NON VERIFICATA
        // -----------------------
        if (!emailVerified) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Verifica email'),
              actions: [
                IconButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Devi verificare la tua email per continuare.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await user.sendEmailVerification();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email di verifica inviata')),
                          );
                        }
                      },
                      child: const Text('Reinvia email di verifica'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        await user.reload();
                        setState(() => _refresh++);
                      },
                      child: const Text('Ho verificato, aggiorna'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // -----------------------
        // TELEFONO NON VERIFICATO
        // -----------------------
        if (!phoneVerified) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/phone');
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // -----------------------
        // CREA PROFILO SU FIRESTORE (UNA VOLTA)
        // -----------------------
        if (_profileError != null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Errore'),
              actions: [
                IconButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_profileError!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _profileError = null;
                        _creatingProfile = false;
                        _refresh++;
                      });
                    },
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!_creatingProfile) {
          _creatingProfile = true;

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              // ricaviamo nome/cognome dal displayName salvato in Register
              final display = (user.displayName ?? '').trim();
              final parts = display.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
              final firstName = parts.isNotEmpty ? parts.first : '';
              final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

              await FirestoreService.createUserIfNotExists(
                UserProfile(
                  uid: user.uid,
                  email: user.email ?? '',
                  phone: user.phoneNumber ?? '',
                  role: 'customer',
                  firstName: firstName,
                  lastName: lastName,
                ),
              );

              if (mounted) setState(() => _refresh++);
            } catch (e) {
              if (mounted) setState(() => _profileError = 'Firestore error: $e');
            }
          });
        }

        return const CustomerHome();
      },
    );
  }
}