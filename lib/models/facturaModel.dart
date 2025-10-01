import 'package:proyectocompras/models/productoFacturaModel.dart';

class FacturaModel {
  final int? id;
  double precio;
  String fecha;
  String usuariouuid;
  List<ProductoFacturaModel> productos;

  FacturaModel({
    this.id,
    required this.precio,
    required this.fecha,
    required this.usuariouuid,
    required this.productos,
  });

  factory FacturaModel.fromMap(Map<String, dynamic> map, List<ProductoFacturaModel> productos) {
    return FacturaModel(
      id: map['id'] as int?,
      precio: (map['precio'] as num).toDouble(),
      fecha: map['fecha'] as String,
      usuariouuid: map['usuariouuid'] as String,
      productos: productos,
    );
  }
}
