class ProductoFacturaModel {
  final String nombre;
  final int cantidad;
  final double precioUnidad;

  ProductoFacturaModel({
    required this.nombre,
    required this.cantidad,
    required this.precioUnidad,
  });

  factory ProductoFacturaModel.fromMap(Map<String, dynamic> map) {
    return ProductoFacturaModel(
      nombre: map['productos']['nombre'],
      cantidad: map['cantidad'] as int,
      precioUnidad: (map['preciounidad'] as num).toDouble(),
    );
  }
}
