import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/productoProvider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/productoModel.dart';

class ProductosRecetaProvider extends ChangeNotifier {
  final SupabaseClient database;
  final int recetaId;

  ProductosRecetaProvider(this.database, this.recetaId);

  List<ProductoModel> _productos = [];
  List<ProductoModel> get productos => _productos;

  /// Carga los productos asociados a una receta desde la base de datos.
  ///
  /// Flujo principal:
  /// - Busca en la tabla receta_producto los productos que pertenecen a la receta actual.
  /// - Convierte los datos obtenidos en una lista de objetos [ProductoModel].
  /// - Guarda la lista en [_productos].
  /// - Notifica a los listeners para actualizar la interfaz.
  Future<void> cargarProductos() async {
    final res = await database
        .from('receta_producto')
        .select('productos(id, nombre, descripcion, precio, foto, supermercado)')
        .eq('idreceta', recetaId);

    _productos = (res as List)
        .map((map) => ProductoModel.fromMap(map['productos']))
        .toList();

    notifyListeners();
  }

  /// Añade un producto a la receta y lo guarda en la base de datos.
  ///
  /// Flujo principal:
  /// - Añade el producto a la lista local y actualiza la interfaz.
  /// - Intenta guardar la relación en la tabla receta_producto.
  /// - Si ocurre un error, elimina el producto de la lista local y vuelve a notificar los cambios.
  Future<void> addProducto(ProductoModel producto) async {
    _productos.add(producto);
    notifyListeners();

    try {
      await database.from('receta_producto').insert({
        'idreceta': recetaId,
        'idproducto': producto.id,
      });
    } catch (e) {
      _productos.removeWhere((p) => p.id == producto.id);
      notifyListeners();
      debugPrint("Error añadiendo producto: $e");
    }
  }

  /// Elimina un producto de la receta y actualiza la base de datos.
  ///
  /// Flujo principal:
  /// - Guarda una copia de la lista actual de productos por si hay errores.
  /// - Elimina el producto de la lista local y actualiza la interfaz.
  /// - Intenta borrar la relación en la tabla receta_producto.
  /// - Si ocurre un error, restaura la lista original y vuelve a notificar los cambios.
  Future<void> removeProducto(int productoId) async {
    final backup = List<ProductoModel>.from(_productos);
    _productos.removeWhere((p) => p.id == productoId);
    notifyListeners();

    try {
      await database
          .from('receta_producto')
          .delete()
          .eq('idreceta', recetaId)
          .eq('idproducto', productoId);
    } catch (e) {
      _productos = backup;
      notifyListeners();
      debugPrint("Error eliminando producto: $e");
    }
  }

  /// Sincroniza los productos seleccionados con los que tiene guardados la receta.
  ///
  /// Flujo principal:
  /// - Compara los productos actuales con los seleccionados por el usuario.
  /// - Calcula cuáles hay que agregar y cuáles eliminar.
  /// - Añade los productos nuevos llamando a addProducto.
  /// - Elimina los que ya no están seleccionados llamando a removeProducto.
  /// - Deja la base de datos y la lista local con la misma información.
  Future<void> syncProductos(BuildContext context, Set<int> seleccionados) async {
    final actuales = _productos.map((p) => p.id!).toSet();

    final aAgregar = seleccionados.difference(actuales);
    final aEliminar = actuales.difference(seleccionados);

    final productoProvider = context.read<ProductoProvider>();

    for (final id in aAgregar) {
      final producto = productoProvider.productos.firstWhere((p) => p.id == id);
      await addProducto(producto);
    }

    for (final id in aEliminar) {
      await removeProducto(id);
    }
  }
}
