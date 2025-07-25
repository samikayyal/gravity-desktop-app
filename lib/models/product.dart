class Product {
  final int id;
  final String name;
  final int price;
  final int effectiveStock;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.effectiveStock,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['product_id'] as int,
      name: map['name'] as String,
      price: map['price'] as int,
      effectiveStock: map['quantity_available'] as int,
    );
  }

  // A copyWith method for easily creating a modified copy of a product instance
  Product copyWith({
    int? id,
    String? name,
    int? price,
    int? effectiveStock,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      effectiveStock: effectiveStock ?? this.effectiveStock,
    );
  }
}
