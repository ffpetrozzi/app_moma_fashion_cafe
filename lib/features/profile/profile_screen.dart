import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

String _toE164(String s) {
  final p = s.trim().replaceAll(' ', '');
  if (p.isEmpty) return p;
  if (p.startsWith('+')) return p;
  // se uno scrive 39... senza +, lo sistemiamo
  return '+$p';
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();

  bool _loading = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _normPhone(String s) => s.trim().replaceAll(' ', '');

  Future<String?> _askSmsCode() async {
    String sms = '';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Inserisci codice SMS'),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Codice (6 cifre)',
          ),
          onChanged: (v) => sms = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(sms),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  Future<bool> _verifyAndUpdatePhone({
      required User user,
      required String newPhoneE164,
      required DocumentReference<Map<String, dynamic>> userDoc,
    }) async {
      setState(() => _loading = true);

      final completer = Completer<bool>();

      try {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: newPhoneE164,

          verificationCompleted: (PhoneAuthCredential cred) async {
            // Auto-verifica (può succedere su Android)
            try {
              await user.linkWithCredential(cred);
            } catch (_) {}

            await userDoc.set({
              'phone': newPhoneE164,
              'phoneVerified': true,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            if (!completer.isCompleted) completer.complete(true);
          },

          verificationFailed: (FirebaseAuthException e) async {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Verifica fallita: ${e.message ?? e.code}')),
              );
            }
            if (!completer.isCompleted) completer.complete(false);
          },

          codeSent: (String verificationId, int? resendToken) async {
            if (!mounted) {
              if (!completer.isCompleted) completer.complete(false);
              return;
            }
            
            final code = await _askSmsCode();
            if (code == null || code.isEmpty) {
              if (!completer.isCompleted) completer.complete(false);
              return;
            }

            final cred = PhoneAuthProvider.credential(
              verificationId: verificationId,
              smsCode: code,
            );

            try {
              await user.linkWithCredential(cred);
            } catch (_) {}

            await userDoc.set({
              'phone': newPhoneE164,
              'phoneVerified': true,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            if (!completer.isCompleted) completer.complete(true);
          },

          codeAutoRetrievalTimeout: (String verificationId) {
            // Se va in timeout e non abbiamo completato, segniamo fallito
            if (!completer.isCompleted) completer.complete(false);
          },
        );

        // Aspetta davvero che finisca (codeSent o verificationCompleted o fail/timeout)
        final ok = await completer.future;
        return ok;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

  Future<void> _save({
    required User user,
    required DocumentReference<Map<String, dynamic>> userDoc,
    required Map<String, dynamic> currentData,
  }) async {
    if (!_formKey.currentState!.validate()) return;

    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    final phoneInput = _toE164(_phone.text);
    final currentPhone = _toE164((currentData['phone'] ?? '').toString());

    final email = user.email ?? '';
    final currentVerified = (currentData['phoneVerified'] as bool?) ?? false;

    setState(() => _loading = true);

    try {
      // Salva nome/cognome/email subito
      await userDoc.set({
        'firstName': first,
        'lastName': last,
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Se il telefono è cambiato o non è verificato → verifichiamo via SMS
      if (phoneInput != currentPhone || !currentVerified) {
        // IMPORTANTE: Firebase Phone Auth vuole E.164. Tu inserisci già +39..., quindi ok.
        final newPhoneE164 = phoneInput.startsWith('+') ? phoneInput : '+$phoneInput';

        // Mettiamo temporaneamente verified=false finché non completa
        await userDoc.set({
          'phone': newPhoneE164,
          'phoneVerified': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Verifica via SMS e poi updatePhoneNumber + phoneVerified=true
        final ok = await _verifyAndUpdatePhone(
          user: user,
          newPhoneE164: newPhoneE164,
          userDoc: userDoc,
        );

        if (!ok) {
          // Resta nella pagina, così l’utente può riprovare
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Verifica telefono non completata')),
            );
          }
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo salvato ✅')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Profilo'),
        ),
        body: const Center(child: Text('Devi essere loggato')),
      );
    }

    final uid = user.uid;
    final email = user.email ?? '';
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profilo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDoc.snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() ?? <String, dynamic>{};

          // Precompila UNA volta (così non ti riscrive mentre digiti)
          if (!_prefilled) {
            _prefilled = true;
            _firstName.text = (data['firstName'] ?? '').toString();
            _lastName.text = (data['lastName'] ?? '').toString();
            _phone.text = (data['phone'] ?? '').toString();
          }

          final phoneVerified = (data['phoneVerified'] as bool?) ?? false;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(child: Icon(Icons.person)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Account',
                                  style: TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(email.isEmpty ? '—' : email,
                                  style: const TextStyle(color: Colors.black54)),
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
                                      color: phoneVerified ? Colors.green : Colors.orange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(
                      labelText: 'Nome *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Inserisci il nome';
                      if (s.length < 2) return 'Nome troppo corto';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(
                      labelText: 'Cognome *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Inserisci il cognome';
                      if (s.length < 2) return 'Cognome troppo corto';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefono (formato +39...) *',
                      border: OutlineInputBorder(),
                      helperText: 'Se cambi numero, verrà richiesto un SMS.',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      final s = _normPhone(v ?? '');
                      if (s.isEmpty) return 'Inserisci il numero di telefono';
                      if (!s.startsWith('+')) return 'Usa formato internazionale (es. +39333...)';
                      if (s.length < 8) return 'Numero non valido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () => _save(user: user, userDoc: userDoc, currentData: data),
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Salva'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}