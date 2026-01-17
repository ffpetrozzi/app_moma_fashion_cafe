import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../cart/cart_provider.dart';
import '../../app/widgets/app_snackbar.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _placeOrder(String paymentMethod) async {
    final cart = context.read<CartProvider>();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || cart.items.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'items': cart.items.map((i) {
          return {
            'cocktailId': i.cocktailId,
            'name': i.name,
            'variant': i.variantLabel,
            'price': i.price,
            'qty': i.qty,
          };
        }).toList(),
        'total': cart.total,
        'paymentMethod': paymentMethod,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      cart.clear();

      if (mounted) {
        context.go('/'); // torniamo alla Home
        AppSnackBar.show(
          context,
          'Ordine inviato 🍸',
          type: AppSnackBarType.success,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final accent = const Color(0xFFB5654B);
    final accentDark = const Color(0xFF7A3E2B);
    final cream = const Color(0xFFF7F2EC);
    final cardDecoration = BoxDecoration(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Checkout'),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: cart.items.isEmpty
                      ? Center(
                          child: Text(
                            'Carrello vuoto',
                            style: TextStyle(
                              color: accentDark.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: cardDecoration,
                              child: Text(
                                'Riepilogo ordine',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: accentDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...cart.items.map((i) {
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: cardDecoration,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            i.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: accentDark,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            i.variantLabel,
                                            style: const TextStyle(color: Colors.black54),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'x${i.qty}',
                                            style: TextStyle(
                                              color: accentDark.withOpacity(0.8),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '€${(i.lineTotal).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: accentDark,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: cardDecoration,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Totale',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: accentDark,
                                    ),
                                  ),
                                  Text(
                                    '€${cart.total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: accentDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: cream,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _loading ? null : () => _placeOrder('cash'),
                    child: const Text('Paga in contanti'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentDark,
                      side: BorderSide(color: accentDark.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _loading ? null : () => _placeOrder('stripe'),
                    child: const Text('Paga con carta'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
