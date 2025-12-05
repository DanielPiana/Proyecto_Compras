/// Modelo que representa un producto con su información y código de barras
class ProductModel {
  final int? id;
  String? barCode;
  String name;
  String description;
  double price;
  String supermarket;
  String userUuid;
  String photo;

  ProductModel({
    required this.id,
    required this.barCode,
    required this.name,
    required this.description,
    required this.price,
    required this.supermarket,
    required this.userUuid,
    required this.photo,
  });

  /// Crea un ProductModel desde un Map de la base de datos
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as int,
      barCode: map['codbarras']?.toString() ?? '',
      name: map['nombre']?.toString() ?? '',
      description: map['descripcion']?.toString() ?? '',
      price: (map['precio'] as num?)?.toDouble() ?? 0.0,
      supermarket: map['supermercado']?.toString() ?? 'Sin supermercado',
      userUuid: map['usuariouuid']?.toString() ?? '',
      photo: map['foto']?.toString() ?? '',
    );
  }

  /// Convierte el ProductModel a un Map para la base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codbarras': barCode,
      'nombre': name,
      'descripcion': description,
      'precio': price,
      'supermercado': supermarket,
      'usuariouuid': userUuid,
      'foto': photo,
    };
  }
}
