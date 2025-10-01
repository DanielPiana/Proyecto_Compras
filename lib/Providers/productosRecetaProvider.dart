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
      debugPrint("❌ Error añadiendo producto: $e");
    }
  }

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
      debugPrint("❌ Error eliminando producto: $e");
    }
  }

  Future<void> syncProductos(BuildContext context, Set<int> seleccionados,) async {
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
