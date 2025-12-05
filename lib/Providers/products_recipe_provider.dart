import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/products_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';

class ProductsRecipeProvider extends ChangeNotifier {
  final SupabaseClient database;
  final int recipeId;

  ProductsRecipeProvider(this.database, this.recipeId);

  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

  /// Carga los productos asociados a una receta desde la base de datos.
  ///
  /// Flujo principal:
  /// - Busca en la tabla receta_producto los productos que pertenecen a la receta actual.
  /// - Convierte los datos obtenidos en una lista de objetos [ProductModel].
  /// - Guarda la lista en [_products].
  /// - Notifica a los listeners para actualizar la interfaz.
  Future<void> loadProducts() async {
    final res = await database
        .from('receta_producto')
        .select('productos(id, nombre, descripcion, precio, foto, supermercado)')
        .eq('idreceta', recipeId);

    _products = (res as List)
        .map((map) => ProductModel.fromMap(map['productos']))
        .toList();

    notifyListeners();
  }

  /// Añade un producto a la receta y lo guarda en la base de datos.
  ///
  /// Flujo principal:
  /// - Añade el producto a la lista local y actualiza la interfaz.
  /// - Intenta guardar la relación en la tabla receta_producto.
  /// - Si ocurre un error, elimina el producto de la lista local y vuelve a notificar los cambios.
  Future<void> addProduct(ProductModel product) async {
    _products.add(product);
    notifyListeners();

    try {
      await database.from('receta_producto').insert({
        'idreceta': recipeId,
        'idproducto': product.id,
      });
    } catch (e) {
      _products.removeWhere((p) => p.id == product.id);
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
  Future<void> removeProduct(int productId) async {
    final backup = List<ProductModel>.from(_products);
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();

    try {
      await database
          .from('receta_producto')
          .delete()
          .eq('idreceta', recipeId)
          .eq('idproducto', productId);
    } catch (e) {
      _products = backup;
      notifyListeners();
      debugPrint("Error eliminando producto: $e");
    }
  }

  /// Sincroniza los productos seleccionados con los que tiene guardados la receta.
  ///
  /// Flujo principal:
  /// - Compara los productos actuales con los seleccionados por el usuario.
  /// - Calcula cuáles hay que agregar y cuáles eliminar.
  /// - Añade los productos nuevos llamando a addProduct.
  /// - Elimina los que ya no están seleccionados llamando a removeProduct.
  /// - Deja la base de datos y la lista local con la misma información.
  Future<void> syncProducts(BuildContext context, Set<int> newSelectedProducts) async {
    final currentSelectedProducts = _products.map((p) => p.id!).toSet();

    final productsToAdd = newSelectedProducts.difference(currentSelectedProducts);
    final productsToDelete = currentSelectedProducts.difference(newSelectedProducts);

    final productProvider = context.read<ProductProvider>();

    for (final id in productsToAdd) {
      final product = productProvider.products.firstWhere((p) => p.id == id);
      await addProduct(product);
    }

    for (final id in productsToDelete) {
      await removeProduct(id);
    }
  }
}
