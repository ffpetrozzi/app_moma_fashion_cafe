import 'package:flutter/material.dart';
import 'cart_item.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList();

  int get totalQty => _items.values.fold(0, (s, i) => s + i.qty);
  double get total => _items.values.fold(0.0, (s, i) => s + i.lineTotal);

  void add({
    required String cocktailId,
    required String name,
    required String variantKey,
    required String variantLabel,
    required double price,
    int qty = 1,
  }) {
    final k = '$cocktailId::$variantKey';
    final existing = _items[k];
    if (existing != null) {
      existing.qty += qty;
    } else {
      _items[k] = CartItem(
        cocktailId: cocktailId,
        name: name,
        variantKey: variantKey,
        variantLabel: variantLabel,
        price: price,
        qty: qty,
      );
    }
    notifyListeners();
  }

  void inc(String key) {
    final it = _items[key];
    if (it == null) return;
    it.qty += 1;
    notifyListeners();
  }

  void dec(String key) {
    final it = _items[key];
    if (it == null) return;
    it.qty -= 1;
    if (it.qty <= 0) _items.remove(key);
    notifyListeners();
  }

  void remove(String key) {
    _items.remove(key);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}