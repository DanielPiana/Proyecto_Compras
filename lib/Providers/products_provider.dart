import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:food_manager/Providers/shopping_list_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import 'package:http/http.dart' as http;

import '../utils/text_normalizer.dart';

class ProductProvider with ChangeNotifier {
  final SupabaseClient database;
  String? userId;

  ProductProvider(this.database, this.userId);

  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ProductModel> filteredProducts = [];
  String lastQuery = '';

  bool get isFiltering =>
      filteredProducts.isNotEmpty || lastQuery.isNotEmpty;

  // METODO PARA CUANDO EL USUARIO HACE UNA BUSQUEDA
  void setSearchText(String value) {
    lastQuery = value;

    if (value.trim().isEmpty) {
      filteredProducts = [];
      notifyListeners();
      return;
    }

    final query = normalizeText(value);

    filteredProducts = products.where((p) {
      final name = normalizeText(p.name ?? "");
      final description = normalizeText(p.description ?? "");
      final supermarket = normalizeText(p.supermarket ?? "");

      return name.contains(query) ||
          description.contains(query) ||
          supermarket.contains(query);
    }).toList();

    notifyListeners();
  }


  // METODO PARA AGRUPAR PRODUCTOS FILTRADOS
  Map<String, List<ProductModel>> get groupedProducts {
    final list = isFiltering ? filteredProducts : products;

    final Map<String, List<ProductModel>> grouped = {};

    for (final p in list) {
      if (!grouped.containsKey(p.supermarket)) {
        grouped[p.supermarket] = [];
      }
      grouped[p.supermarket]!.add(p);
    }

    return grouped;
  }


  void clearSearch() {
    lastQuery = '';
    filteredProducts = [];
    notifyListeners();
  }

  /// Obtiene los productos agrupados por supermercado.
  ///
  /// Flujo principal:
  /// - Recorre la lista interna de productos [_products].
  /// - Agrupa cada producto según su supermercado (si no tiene, se asigna "Sin supermercado").
  /// - Normaliza el nombre del supermercado (primera letra mayúscula, resto minúsculas).
  /// - Ordena los productos alfabéticamente dentro de cada supermercado.
  /// - Ordena también los supermercados alfabéticamente por nombre.
  Map<String, List<ProductModel>> get productsBySupermarket {
    final Map<String, List<ProductModel>> grouped = {};

    for (var p in _products) {
      String supermarket = p.supermarket.isNotEmpty
          ? '${p.supermarket[0].toUpperCase()}${p.supermarket.substring(1).toLowerCase()}'
          : 'Sin supermercado';

      grouped.putIfAbsent(supermarket, () => []);
      grouped[supermarket]!.add(p);
    }

    // ORDENAR LOS PRODUCTOS EN CADA SUPERMERCADO
    for (var lista in grouped.values) {
      lista.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    // DEVOLVEMOS UN MAPA ORDENADO POR CLAVE (SUPERMERCADO)
    final sortedKeys = grouped.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final Map<String, List<ProductModel>> sortedSupermarkets = {
      for (var key in sortedKeys) key: grouped[key]!
    };

    return sortedSupermarkets;
  }

  /// METODO PARA ESTABLECER UN USUARIO Y RECARGAR SUS PRODUCTOS
  Future<void> setUserAndReload(String? uid) async {
    userId = uid;
    await loadProducts();
  }

  /// Carga los productos del usuario desde la base de datos.
  ///
  /// Flujo principal:
  /// - Verifica si existe un [userId] válido; si no lo hay, limpia la lista de productos y notifica a los listeners.
  /// - Consulta la tabla `productos` en la base de datos, filtrando por el [userId].
  /// - Convierte los resultados en una lista de [ProductModel].
  /// - Ordena los productos mediante [sortProducts].
  /// - Notifica a los listeners para actualizar la UI.
  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    if (userId == null || userId!.isEmpty) {
      _products = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    final data = await database
        .from('productos')
        .select()
        .eq('usuariouuid', userId!);

    _products = data.map<ProductModel>((p) => ProductModel.fromMap(p)).toList();

    sortProducts(_products);

    _isLoading = false;
    notifyListeners();
  }

  // SIN USO DE MOMENTO
  /// Obtiene los productos del usuario desde la base de datos.
  ///
  /// Flujo principal:
  /// - Consulta la tabla `productos` en la base de datos, filtrando por el [userId].
  /// - Convierte el resultado en una lista de instancias de [ProductModel].
  /// - Si ocurre un error durante la consulta o la conversión, se captura la excepción,
  ///   se imprime un log de error y se retorna una lista vacía.
  Future<List<ProductModel>> getProducts() async {
    try {
      final res = await database
          .from('productos')
          .select()
          .eq('usuariouuid', userId!);

      return (res as List)
          .map((map) => ProductModel.fromMap(map))
          .toList();
    } catch (e) {
      debugPrint("Error al obtener productos: $e");
      return [];
    }
  }


  /// METODO PARA ORDENAR PRODUCTOS ALFABETICAMENTE
  List<ProductModel> sortProducts(List<ProductModel> products) {
    products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return products;
  }


  /// Crea un nuevo producto en la base de datos y lo añade a la lista local.
  ///
  /// Flujo principal:
  /// - Realiza una copia de respaldo de la lista local de productos.
  /// - Inserta el [newProduct] en la tabla `productos` de la base de datos.
  /// - Si la inserción devuelve un resultado, reemplaza el producto temporal en la lista local
  ///   con la versión creada desde la base de datos (incluyendo su ID generado).
  /// - Ordena los productos y notifica a los listeners para actualizar la UI.
  /// - Si ocurre un error, restaura la lista local desde la copia de respaldo,
  ///   notifica a los listeners y relanza la excepción.
  Future<void> createProduct(ProductModel newProduct) async {
    final backupProducts = List<ProductModel>.from(_products);

    try {
      final response = await database.from('productos').insert({
        'nombre': newProduct.name,
        'descripcion': newProduct.description,
        'precio': newProduct.price,
        'supermercado': newProduct.supermarket,
        'usuariouuid': newProduct.userUuid,
        'foto': newProduct.photo,
        'codbarras': newProduct.barCode
      }).select();

      if (response.isNotEmpty) {
        final index = _products.indexOf(newProduct);
        if (index != -1) {
          _products[index] = ProductModel.fromMap(response[0]);
          sortProducts(_products);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error al crear producto: $e");
      _products = backupProducts;
      notifyListeners();
      rethrow;
    }
  }


  /// Actualiza un producto existente en la base de datos y en la lista local.
  ///
  /// Flujo principal:
  /// - Realiza una copia de respaldo de la lista local de productos.
  /// - Busca el producto en la lista local y lo reemplaza por la versión nueva.
  /// - Ordena los productos y notifica a los listeners para refrescar la UI.
  /// - Actualiza también el producto en el [ShoppingListProvider] para mantener la coherencia local.
  /// - Intenta actualizar el producto en la tabla `productos` de la base de datos.
  /// - Actualiza en paralelo los registros de la tabla `compra` relacionados con ese producto.
  /// - Si ocurre un error, restaura la lista local desde el respaldo,
  ///   notifica a los listeners y relanza la excepción.
  Future<void> updateProduct(ProductModel updatedProduct, ShoppingListProvider compraProvider) async {
    final backupProducts = List<ProductModel>.from(_products);

    final index = _products.indexWhere((p) => p.id == updatedProduct.id);
    if (index != -1) {
      _products[index] = updatedProduct;
      sortProducts(_products);
      notifyListeners();
    }

    compraProvider.updateLocalProduct(updatedProduct);

    try {
      await database.from('productos').update({
        'nombre': updatedProduct.name,
        'descripcion': updatedProduct.description,
        'precio': updatedProduct.price,
        'supermercado': updatedProduct.supermarket,
        'usuariouuid': updatedProduct.userUuid,
        'foto': updatedProduct.photo,
        'codbarras' : updatedProduct.barCode,
      }).eq('id', updatedProduct.id!)
          .eq('usuariouuid', updatedProduct.userUuid);

      await database.from('compra').update({
        'nombre': updatedProduct.name,
        'precio': updatedProduct.price,
      }).eq('idproducto', updatedProduct.id!)
          .eq('usuariouuid', updatedProduct.userUuid);

    } catch (e) {
      debugPrint("Error al actualizar producto: $e");
      _products = backupProducts;
      notifyListeners();
      rethrow;
    }
  }

  bool existsWithBarCode(String code) {
    if (code.trim().isEmpty) return false;

    return products.any((p) => (p.barCode ?? '') == code.trim());
  }


  /// Elimina un producto de la base de datos y de la lista local.
  ///
  /// Flujo principal:
  /// - Realiza una copia de respaldo de la lista local de productos.
  /// - Elimina el producto de la lista local según su [id].
  /// - Elimina también el producto en el [ShoppingListProvider] para mantener coherencia local.
  /// - Notifica a los listeners para refrescar la UI.
  /// - Intenta eliminar el producto en la tabla `productos` de la base de datos.
  /// - Si ocurre un error, restaura la lista local desde el respaldo,
  ///   vuelve a ordenar los productos, notifica a los listeners y relanza la excepción.
  Future<void> deleteProduct(BuildContext context, int id) async {
    final backupProducts = List<ProductModel>.from(_products);

    _products.removeWhere((p) => p.id == id);
    context.read<ShoppingListProvider>().deleteLocalProduct(id);
    notifyListeners();

    try {
      await database.from('productos').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error al eliminar producto: $e");
      _products = backupProducts;
      sortProducts(_products);
      notifyListeners();

      rethrow;
    }
  }


  /// Obtiene la lista de supermercados asociados a los productos del usuario.
  ///
  /// Flujo principal:
  /// - Si existen productos cargados en la lista local, devuelve los supermercados únicos
  ///   presentes en dichos productos (ignorando los vacíos).
  /// - Si no hay productos cargados, consulta la tabla `productos` en la base de datos,
  ///   filtrando por el [userId], y extrae los supermercados únicos.
  Future<List<String>> getSupermarkets() async {
    // SI HAY PRODUCTOS CARGADOS, USAMOS LA LISTA LOCAL
    if (_products.isNotEmpty) {
      return _products
          .map((p) => p.supermarket)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    }

    // SI NO HAY PRODUCTOS MARCADOS CONSULTAMOS LA BASE DE DATOS
    final products = await database
        .from('productos')
        .select()
        .eq('usuariouuid', userId!);

    return (products as List)
        .map((p) => p['supermercado'] as String)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  /// METODO PARA AÑADIR UN PRODUCTO A LA LISTA LOCAL Y NOTIFICAR A LOS CONSTRUCTORES
  void addLocalProduct(ProductModel product) {
    _products.add(product);
    notifyListeners();
  }

  /// METODO PARA ELIMINAR UN PRODUCTO DE LA LISTA LOCAL Y NOTIFICAR A LOS CONSTRUCTORES
  void removeLocalProduct(int productId) {
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
  }

  /// METODO PARA ACTUALIZAR UN PRODUCTO DE LA LISTA LOCAL Y NOTIFICAR A LOS CONSTRUCTORES
  void updateLocalProduct(int index, ProductModel updatedProduct) {
    if (index >= 0 && index < _products.length) {
      _products[index] = updatedProduct;
      notifyListeners();
    }
  }
}