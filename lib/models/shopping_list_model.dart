/// Modelo que representa un producto en la lista de compras
/// con cantidad, estado de marcado y supermercado asociado
class ShoppingListModel {
  final int productId;
  String name;
  double price;
  int quantity;
  int marked;
  String userUuid;
  String supermarket;

  ShoppingListModel({
    required this.productId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.marked = 0,
    required this.userUuid,
    required this.supermarket,
  });

  /// Crea un ShoppingListModel desde un Map de la base de datos
  factory ShoppingListModel.fromMap(Map<String, dynamic> map) {
    return ShoppingListModel(
      productId: map['idproducto'],
      name: map['nombre'],
      price: (map['precio'] as num).toDouble(),
      quantity: map['cantidad'] ?? 1,
      marked: map['marcado'] ?? 0,
      userUuid: map['usuariouuid'],
      supermarket: map['productos']?['supermercado'] ?? 'Sin supermercado',
    );
  }
}
