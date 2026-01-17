import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../cart/cart_provider.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _q = '';
  String _cat = 'Tutti';

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final accent = const Color(0xFFB5654B);
    final accentDark = const Color(0xFF7A3E2B);

    final col = FirebaseFirestore.instance
        .collection('cocktails')
        .where('isActive', isEqualTo: true)
        .orderBy('sort');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Menu Cocktail'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: accentDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          ),
          InkWell(
            onTap: () => context.push('/cart'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: Text('Carrello (${cart.totalQty})')),
            ),
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
            stream: col.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;

              // categorie dinamiche
              final cats = <String>{'Tutti'};
              for (final d in docs) {
                final c = (d.data()['category'] ?? '').toString();
                if (c.isNotEmpty) cats.add(c);
              }

              final filtered = docs.where((d) {
                final data = d.data();
                final name = (data['name'] ?? '').toString().toLowerCase();
                final cat = (data['category'] ?? '').toString();
                final okQ = _q.isEmpty || name.contains(_q.toLowerCase());
                final okC = _cat == 'Tutti' || cat == _cat;
                return okQ && okC;
              }).toList();

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cerca un cocktail...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.92),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: cats.map((c) {
                          final selected = c == _cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: selected,
                              selectedColor: accent.withOpacity(0.18),
                              labelStyle: TextStyle(
                                color: selected ? accentDark : Colors.black87,
                                fontWeight: FontWeight.w700,
                              ),
                              onSelected: (_) => setState(() => _cat = c),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final doc = filtered[i];
                          final data = doc.data();
                          final name = (data['name'] ?? '').toString();
                          final desc = (data['description'] ?? '').toString();
                          final category = (data['category'] ?? '').toString();
                          final variants =
                              (data['variants'] as Map?)?.cast<String, dynamic>() ?? {};

                          return _CocktailCard(
                            id: doc.id,
                            name: name,
                            category: category,
                            desc: desc,
                            variants: variants,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CocktailCard extends StatelessWidget {
  final String id;
  final String name;
  final String category;
  final String desc;
  final Map<String, dynamic> variants;

  const _CocktailCard({
    required this.id,
    required this.name,
    required this.category,
    required this.desc,
    required this.variants,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final accent = const Color(0xFFB5654B);

    // prendo keys varianti in ordine: base poi premium poi altre
    final keys = variants.keys.toList();
    keys.sort((a, b) {
      if (a == 'base') return -1;
      if (b == 'base') return 1;
      if (a == 'premium') return -1;
      if (b == 'premium') return 1;
      return a.compareTo(b);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
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
          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          if (category.isNotEmpty)
            Text(category, style: const TextStyle(color: Colors.black54)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(desc),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keys.map((k) {
              final v = (variants[k] as Map?)?.cast<String, dynamic>() ?? {};
              final label = (v['label'] ?? k).toString();
              final price = (v['price'] as num?)?.toDouble() ?? 0.0;

              return OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                ),
                onPressed: () {
                  cart.add(
                    cocktailId: id,
                    name: name,
                    variantKey: k,
                    variantLabel: label,
                    price: price,
                    qty: 1,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Aggiunto: $name ($label)')),
                  );
                },
                child: Text('$label • €${price.toStringAsFixed(2)}'),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
