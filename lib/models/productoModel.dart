import 'package:supabase_flutter/supabase_flutter.dart';

class ProductoModel {
  final int id;
  final String codBarras;
  final String nombre;
  final String descripcion;
  final double precio;
  final String supermercado;
  final String usuarioUuid;
  final String foto;

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
