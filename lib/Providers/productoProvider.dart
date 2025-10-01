import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/compraProvider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/productoModel.dart';

class ProductoProvider with ChangeNotifier {
  final SupabaseClient database;
  String? userId;

  ProductoProvider(this.database, this.userId);

  List<ProductoModel> _productos = [];

  List<ProductoModel> get productos => _productos;

  Map<String, List<ProductoModel>> get productosPorSupermercado {
    final Map<String, List<ProductoModel>> agrupados = {};

    for (var p in _productos) {
      String supermercado = p.supermercado.isNotEmpty
          ? '${p.supermercado[0].toUpperCase()}${p.supermercado.substring(1).toLowerCase()}'
          : 'Sin supermercado';

      agrupados.putIfAbsent(supermercado, () => []);
      agrupados[supermercado]!.add(p);
    }

    // ORDENAR LOS PRODUCTOS EN CADA SUPERMERCADO
    for (var lista in agrupados.values) {
      lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    }

    // DEVOLVEMOS UN MAPA ORDENADO POR CLAVE (SUPERMERCADO)
    final sortedKeys = agrupados.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final Map<String, List<ProductoModel>> supermercadosOrdenados = {
      for (var key in sortedKeys) key: agrupados[key]!
    };

    return supermercadosOrdenados;
  }

  Future<void> setUserAndReload(String? uid) async {
    userId = uid;
    await cargarProductos();
  }

  Future<void> cargarProductos() async {
    if (userId == null || userId!.isEmpty) {
      _productos = [];
      notifyListeners();
      return;
    }

    final data = await database
        .from('productos')
        .select()
        .eq('usuariouuid', userId!);

    _productos = data.map<ProductoModel>((p) => ProductoModel.fromMap(p)).toList();

    ordenarProductos(_productos);

    notifyListeners();
  }

  Future<List<ProductoModel>> obtenerProductos() async {
    try {
      final res = await database
          .from('productos')
          .select()
          .eq('usuariouuid', userId!);

      return (res as List)
          .map((map) => ProductoModel.fromMap(map))
          .toList();
    } catch (e) {
      debugPrint("❌ Error al obtener productos: $e");
      return [];
    }
  }

  List<ProductoModel> ordenarProductos(List<ProductoModel> productos) {

    productos.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    return productos;
  }

  Future<void> crearProducto(ProductoModel nuevoProducto) async {
    final backupProductos = List<ProductoModel>.from(_productos);

    try {
      final response = await database.from('productos').insert({
        'nombre': nuevoProducto.nombre,
        'descripcion': nuevoProducto.descripcion,
        'precio': nuevoProducto.precio,
        'supermercado': nuevoProducto.supermercado,
        'usuariouuid': nuevoProducto.usuarioUuid,
        'foto': nuevoProducto.foto,
      }).select();

      if (response.isNotEmpty) {
        final index = _productos.indexOf(nuevoProducto);
        if (index != -1) {
          _productos[index] = ProductoModel.fromMap(response[0]);
          ordenarProductos(_productos);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error al crear producto: $e");
      _productos = backupProductos;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> actualizarProducto(ProductoModel productoActualizado, CompraProvider compraProvider) async {
    final backupProductos = List<ProductoModel>.from(_productos);

    final index = _productos.indexWhere((p) => p.id == productoActualizado.id);
    if (index != -1) {
      _productos[index] = productoActualizado;
      ordenarProductos(_productos);
      notifyListeners();
    }

    compraProvider.actualizarProductoEnCompraLocal(productoActualizado);

    try {
      await database.from('productos').update({
        'nombre': productoActualizado.nombre,
        'descripcion': productoActualizado.descripcion,
        'precio': productoActualizado.precio,
        'supermercado': productoActualizado.supermercado,
        'usuariouuid': productoActualizado.usuarioUuid,
      }).eq('id', productoActualizado.id!)
          .eq('usuariouuid', productoActualizado.usuarioUuid);

      await database.from('compra').update({
        'nombre': productoActualizado.nombre,
        'precio': productoActualizado.precio,
      }).eq('idproducto', productoActualizado.id!)
          .eq('usuariouuid', productoActualizado.usuarioUuid);

    } catch (e) {
      debugPrint("Error al actualizar producto: $e");
      _productos = backupProductos;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> eliminarProducto(BuildContext context, int id) async {
    final backupProductos = List<ProductoModel>.from(_productos);

    _productos.removeWhere((p) => p.id == id);
    context.read<CompraProvider>().eliminarProductoLocal(id);
    notifyListeners();

    try {
      await database.from('productos').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error al eliminar producto: $e");
      _productos = backupProductos;
      ordenarProductos(_productos);
      notifyListeners();

      rethrow;
    }
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
        .eq('usuariouuid', userId!);

    return (productos as List)
        .map((p) => p['supermercado'] as String)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  void addProductoLocal(ProductoModel producto) {
    _productos.add(producto);
    notifyListeners();
  }

  void removeProductoLocal(int idProducto) {
    _productos.removeWhere((p) => p.id == idProducto);
    notifyListeners();
  }

  void updateProductoLocal(int index, ProductoModel productoActualizado) {
    if (index >= 0 && index < _productos.length) {
      _productos[index] = productoActualizado;
      notifyListeners();
    }
  }

}
