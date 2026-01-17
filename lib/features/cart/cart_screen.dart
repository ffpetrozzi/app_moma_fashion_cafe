import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cart_provider.dart';
import 'package:go_router/go_router.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Carrello'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: cart.items.isEmpty
                  ? const Center(child: Text('Carrello vuoto'))
                  : ListView.separated(
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final it = cart.items[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(it.name,
                                        style: const TextStyle(
                                            fontSize: 16, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(it.variantLabel,
                                        style: const TextStyle(color: Colors.black54)),
                                    const SizedBox(height: 6),
                                    Text('€${it.price.toStringAsFixed(2)}'),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => cart.dec(it.key),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${it.qty}', style: const TextStyle(fontSize: 16)),
                              IconButton(
                                onPressed: () => cart.inc(it.key),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                              IconButton(
                                onPressed: () => cart.remove(it.key),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Totale: €${cart.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                ElevatedButton(
                  onPressed: cart.items.isEmpty ? null : () => context.push('/checkout'),
                  child: const Text('Vai al pagamento'),
                )
              ],
            ),
            const SizedBox(height: 10),
            if (cart.items.isNotEmpty)
              OutlinedButton(
                onPressed: cart.clear,
                child: const Text('Svuota carrello'),
              ),
          ],
        ),
      ),
    );
  }
}