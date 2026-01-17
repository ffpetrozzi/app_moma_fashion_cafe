import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PhoneVerifyScreen extends StatefulWidget {
  const PhoneVerifyScreen({super.key});

  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();

  String? _verificationId;
  bool _loading = false;
  String? _error;

  Future<void> _sendCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phone.text.trim(),
      verificationCompleted: (credential) async {
        // Auto-verifica su alcuni dispositivi
        await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
        if (mounted) context.go('/');
      },
      verificationFailed: (e) {
        setState(() {
          _error = e.message ?? 'Errore verifica telefono';
          _loading = false;
        });
      },
      codeSent: (verificationId, _) {
        setState(() {
          _verificationId = verificationId;
          _loading = false;
        });
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _verifyCode() async {
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _code.text.trim(),
      );

      await FirebaseAuth.instance.currentUser?.linkWithCredential(cred);
      if (mounted) context.go('/');
    } catch (_) {
      setState(() => _error = 'Codice non valido');
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waitingForCode = _verificationId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Verifica telefono')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Numero di telefono',
                hintText: '+39...',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            if (waitingForCode)
              TextField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Codice SMS'),
                keyboardType: TextInputType.number,
              ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : (waitingForCode ? _verifyCode : _sendCode),
                child: Text(waitingForCode ? 'Verifica' : 'Invia codice'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}