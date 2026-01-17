class CartItem {
  final String cocktailId;
  final String name;
  final String variantKey; // es: base, premium
  final String variantLabel; // es: Base, Premium
  final double price;
  int qty;

  CartItem({
    required this.cocktailId,
    required this.name,
    required this.variantKey,
    required this.variantLabel,
    required this.price,
    required this.qty,
  });

  String get key => '$cocktailId::$variantKey';
  double get lineTotal => price * qty;
}