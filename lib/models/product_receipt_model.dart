
/// Modelo que representa un producto dentro de una factura/ticket
/// con su cantidad y precio unitario
class ProductReceiptModel {
  final String name;
  final int quantity;
  final double unitPrice;

  ProductReceiptModel({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  /// Crea un ProductReceiptModel desde un Map de la base de datos
  factory ProductReceiptModel.fromMap(Map<String, dynamic> map) {
    return ProductReceiptModel(
      name: map['productos']['nombre'],
      quantity: map['cantidad'] as int,
      unitPrice: (map['preciounidad'] as num).toDouble(),
    );
  }
}
