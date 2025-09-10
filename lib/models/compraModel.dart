class CompraModel {
  final int idProducto;
  final String nombre;
  final double precio;
  int cantidad; // para sumar/restar
  int marcado; // 0 o 1
  final String usuarioUuid;
  final String supermercado;

  CompraModel({
    required this.idProducto,
    required this.nombre,
    required this.precio,
    this.cantidad = 1,
    this.marcado = 0,
    required this.usuarioUuid,
    required this.supermercado,
  });

  factory CompraModel.fromMap(Map<String, dynamic> map) {
    return CompraModel(
      idProducto: map['idproducto'],
      nombre: map['nombre'],
      precio: (map['precio'] as num).toDouble(),
      cantidad: map['cantidad'] ?? 1,
      marcado: map['marcado'] ?? 0,
      usuarioUuid: map['usuariouuid'],
      supermercado: map['productos']?['supermercado'] ?? 'Sin supermercado',
    );
  }
}
