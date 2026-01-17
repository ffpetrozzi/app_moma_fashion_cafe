import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../cart/cart_provider.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ordine inviato 🍸')),
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Checkout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  const Text(
                    'Riepilogo ordine',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  ...cart.items.map((i) {
                    return ListTile(
                      title: Text('${i.name} (${i.variantLabel})'),
                      subtitle: Text('x${i.qty}'),
                      trailing: Text(
                        '€${(i.lineTotal).toStringAsFixed(2)}',
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Totale',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '€${cart.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
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
                onPressed: _loading ? null : () => _placeOrder('cash'),
                child: const Text('Paga in contanti'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loading ? null : () => _placeOrder('stripe'),
                child: const Text('Paga con carta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}