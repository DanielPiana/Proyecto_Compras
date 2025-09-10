import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/productoModel.dart';

class ProductoProvider with ChangeNotifier {
  final SupabaseClient database;
  final String userId;

  ProductoProvider(this.database, this.userId);

  List<ProductoModel> _productos = [];

  List<ProductoModel> get productos => _productos;

  Map<String, List<ProductoModel>> get productosPorSupermercado {
    final Map<String, List<ProductoModel>> agrupados = {};
    for (var p in _productos) {
      final supermercado = p.supermercado.isNotEmpty ? p.supermercado : 'Sin supermercado';
      agrupados.putIfAbsent(supermercado, () => []);
      agrupados[supermercado]!.add(p);
    }
    return agrupados;
  }

  Future<void> cargarProductos() async {
    final data = await database
        .from('productos')
        .select()
        .eq('usuariouuid', userId);

    _productos = data.map<ProductoModel>((p) => ProductoModel.fromMap(p)).toList();
    notifyListeners();
  }

  Future<void> crearProducto({
    required String nombre,
    required String descripcion,
    required double precio,
    required String supermercado,
    required String usuarioUuid,
  }) async {
    // INSERTAMOS EN SUPABASE
    final response = await database.from('productos').insert({
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'supermercado': supermercado,
      'usuariouuid': usuarioUuid,
    }).select(); // select() DEVUELVE EL REGISTRO INSERTADO

    if (response.isNotEmpty) {
      // CONVERTIMOS A ProductoModel Y AÑADIMOS A LA LISTA LOCAL
      final nuevoProducto = ProductoModel.fromMap(response[0]);
      _productos.add(nuevoProducto);
      // NOTIFICAMOS LOS CAMBIOS
      notifyListeners();
    }
  }


  Future<void> actualizarProducto(ProductoModel productoActualizado) async {

    await database.from('productos').update({
      'nombre': productoActualizado.nombre,
      'descripcion': productoActualizado.descripcion,
      'precio': productoActualizado.precio,
      'supermercado': productoActualizado.supermercado,
    }).eq('id', productoActualizado.id);

    // ACTUALIZAMOS LA LISTA LOCAL
    final index = _productos.indexWhere((p) => p.id == productoActualizado.id);
    if (index != -1) {
      _productos[index] = productoActualizado;
      // NOTIFICAMOS LOS CAMBIOS
      notifyListeners();
    }
  }

  Future<void> eliminarProducto(int id) async {
    // BORRAMOS EN SUPABASE
    await database.from('productos').delete().eq('id', id);

    // Y ACTUALIZAMOS LA LISTA LOCAL
    _productos.removeWhere((p) => p.id == id);

    // NOTIFICAMOS LOS CAMBIOS
    notifyListeners();
  }

  Future<List<String>> obtenerSupermercados() async {
    // SI HAY PRODUCTOS CARGADOS, USAMOS LA LISTA LOCAL
    if (_productos.isNotEmpty) {
      return _productos
          .map((p) => p.supermercado)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    }

    // SI NO HAY PRODUCTOS MARCADOS CONSULTAMOS LA BASE DE DATOS
    final productos = await database
        .from('productos')
        .select()
        .eq('usuariouuid', userId);

    return (productos as List)
        .map((p) => p['supermercado'] as String)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }
}
