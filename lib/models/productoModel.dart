
class ProductoModel {
  final int? id;
  String? codBarras;
  String nombre;
  String descripcion;
  double precio;
  String supermercado;
  String usuarioUuid;
  String foto;

  ProductoModel({
    required this.id,
    required this.codBarras,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.supermercado,
    required this.usuarioUuid,
    required this.foto,
  });

  factory ProductoModel.fromMap(Map<String, dynamic> map) {
    return ProductoModel(
      id: map['id'] as int,
      codBarras: map['codbarras']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      descripcion: map['descripcion']?.toString() ?? '',
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      supermercado: map['supermercado']?.toString() ?? 'Sin supermercado',
      usuarioUuid: map['usuariouuid']?.toString() ?? '',
      foto: map['foto']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codbarras': codBarras,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'supermercado': supermercado,
      'usuariouuid': usuarioUuid,
      'foto': foto,
    };
  }
}
