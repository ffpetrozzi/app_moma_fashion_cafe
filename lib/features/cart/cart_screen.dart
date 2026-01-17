import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cart_provider.dart';
import 'package:go_router/go_router.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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
        title: const Text('Carrello'),
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
                      : ListView.separated(
                          itemCount: cart.items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final it = cart.items[i];
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
                                          it.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: accentDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(it.variantLabel,
                                            style: const TextStyle(color: Colors.black54)),
                                        const SizedBox(height: 6),
                                        Text(
                                          '€${it.price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: accentDark.withOpacity(0.8),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => cart.dec(it.key),
                                    icon: const Icon(Icons.remove_circle_outline),
                                    color: accentDark,
                                  ),
                                  Text(
                                    '${it.qty}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: accentDark,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => cart.inc(it.key),
                                    icon: const Icon(Icons.add_circle_outline),
                                    color: accentDark,
                                  ),
                                  IconButton(
                                    onPressed: () => cart.remove(it.key),
                                    icon: const Icon(Icons.delete_outline),
                                    color: accentDark,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: cardDecoration,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Totale: €${cart.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: accentDark,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: cream,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: cart.items.isEmpty ? null : () => context.push('/checkout'),
                        child: const Text('Vai al pagamento'),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (cart.items.isNotEmpty)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentDark,
                      side: BorderSide(color: accentDark.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: cart.clear,
                    child: const Text('Svuota carrello'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
