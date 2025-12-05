import 'package:proyectocompras/models/product_receipt_model.dart';

/// Modelo que representa una factura/ticket con sus productos asociados
class ReceiptModel {
  final int? id;
  double price;
  String date;
  String userUuid;
  List<ProductReceiptModel> products;

  ReceiptModel({
    this.id,
    required this.price,
    required this.date,
    required this.userUuid,
    required this.products,
  });

  /// Crea un ReceiptModel desde un Map de la base de datos
  factory ReceiptModel.fromMap(Map<String, dynamic> map, List<ProductReceiptModel> products) {
    return ReceiptModel(
      id: map['id'] as int?,
      price: (map['precio'] as num).toDouble(),
      date: map['fecha'] as String,
      userUuid: map['usuariouuid'] as String,
      products: products,
    );
  }
}
