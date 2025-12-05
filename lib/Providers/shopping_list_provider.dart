import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/shopping_list_model.dart';
import '../models/product_model.dart';
import 'package:intl/intl.dart';

import '../utils/text_normalizer.dart';


class DuplicateProductException implements Exception {}

class ShoppingListProvider extends ChangeNotifier {
  final SupabaseClient database;
  String? userId;

  // LISTA DE COMPRAS CARGADAS DESDE LA BASE DE DATOS
  List<ShoppingListModel> _shoppingList = [];
  List<ShoppingListModel> get shoppingList => _shoppingList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // LISTA AGRUPADA POR SUPERMERCADO
  Map<String, List<ShoppingListModel>> groupedShopping = {};
  double totalShoppingPrice = 0.0;

  // VARIABLES DE BUSQUEDA
  List<ShoppingListModel> filteredShoppingList = [];
  String lastQuery = '';

  // GETTER PARA MOSTRAR COMPRAS AGRUPADAS (FILTRADAS O TODAS)
  Map<String, List<ShoppingListModel>> get groupedShoppingToShow {
    if (filteredShoppingList.isEmpty && lastQuery.trim().isEmpty) {
      return groupedShopping;
    }

    // Agrupar las compras filtradas por supermercado
    Map<String, List<ShoppingListModel>> filteredGrouped = {};
    for (var shoppingList in filteredShoppingList) {
      filteredGrouped.putIfAbsent(shoppingList.supermarket, () => []);
      filteredGrouped[shoppingList.supermarket]!.add(shoppingList);
    }

    return filteredGrouped;
  }

  ShoppingListProvider(this.database, this.userId);

  void setSearchText(String value) {
    lastQuery = value;

    if (value.trim().isEmpty) {
      filteredShoppingList = [];
      notifyListeners();
      return;
    }

    final query = normalizeText(value);

    filteredShoppingList = _shoppingList.where((c) {
      final name = normalizeText(c.name);
      final supermarket = normalizeText(c.supermarket);

      return name.contains(query) || supermarket.contains(query);
    }).toList();

    notifyListeners();
  }

  /// METODO PARA MARCAR O DESMARCAR UN PRODUCTO
  void toggleMarked(ShoppingListModel product) {
    product.marked = product.marked == 1 ? 0 : 1;

    //ACTUALIZAMOS EL PRECIO TOTAL
    if (product.marked == 1) {
      totalShoppingPrice += product.price * product.quantity;
    } else {
      totalShoppingPrice -= product.price * product.quantity;
    }
    notifyListeners();
  }

  /// METODO PARA ESTABLECER EL USUARIO Y CARGAR SUS DATOS
  Future<void> setUserAndReload(String? uuid) async {
    userId = uuid;
    if (uuid == null) {
      _shoppingList = [];
      notifyListeners();
      return;
    }
    await loadShoppingList();
  }

  /// Carga la lista de compras del usuario desde la base de datos y actualiza el estado local.
  ///
  /// Flujo principal:
  /// - Consulta la tabla `compra` en la base de datos, incluyendo la relación con `productos(supermercado)`,
  ///   filtrando por el [userId].
  /// - Inicializa las estructuras locales (`_compras`, `comprasAgrupadas`, `precioTotalCompra`).
  /// - Convierte los resultados en instancias de [ShoppingListModel] y los guarda en la lista local.
  /// - Ordena las compras mediante [sortShoppingList].
  /// - Agrupa las compras por supermercado, asegurando nueva referencia del `Map` en cada iteración
  ///   para forzar la recarga en la UI.
  /// - Calcula el precio total de la compra sumando los productos marcados.
  /// - Notifica a los listeners para refrescar la interfaz.
  Future<void> loadShoppingList() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await database
          .from('compra')
          .select('*, productos(supermercado)')
          .eq('usuariouuid', userId!);

      final List products = response as List;

      _shoppingList = [];
      groupedShopping = {};
      totalShoppingPrice = 0.0;

      // Construimos la lista local
      for (var p in products) {
        final shoppingList = ShoppingListModel.fromMap(p);
        _shoppingList.add(shoppingList);
      }

      sortShoppingList(_shoppingList);

      // Agrupamos por supermercado
      for (var shoppingList in _shoppingList) {
        final supermarket = shoppingList.supermarket;

        groupedShopping = Map.from(groupedShopping)
          ..putIfAbsent(supermarket, () => [])
          ..[supermarket]!.add(shoppingList);

        if (shoppingList.marked == 1) {
          totalShoppingPrice += shoppingList.price * shoppingList.quantity;
        }
      }
    } catch (e) {
      debugPrint('Error al cargar la lista de compra: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  /// Incrementa en 1 la cantidad de un producto en la lista de compras.
  ///
  /// Flujo principal:
  /// - Recorre todas las listas agrupadas por supermercado en [groupedShopping].
  /// - Busca el producto cuyo [productId] coincida.
  /// - Si se encuentra, incrementa su cantidad en 1.
  /// - Si el producto está marcado (`marcado == 1`), también incrementa el [totalShoppingPrice].
  /// - Si no se encuentra en esa lista, se ignora sin lanzar error.
  /// - Al final, se notifica a los listeners para refrescar la interfaz.
  void incrementQuantity(int productId) {
    groupedShopping.forEach((key, list) {
      try {
        final p = list.firstWhere((p) => p.productId == productId);
        p.quantity += 1;
        if (p.marked == 1) {
          totalShoppingPrice += p.price;
        }
      } catch (e) {
        // NO SE ENCONTRO EL PRODUCTO, NO NECESITAMOS HACER NADA
      }
    });
    notifyListeners();
  }

  /// Decrementa en 1 la cantidad de un producto en la lista de compras.
  ///
  /// Flujo principal:
  /// - Recorre todas las listas agrupadas por supermercado en [groupedShopping].
  /// - Busca el producto cuyo [productId] coincida.
  /// - Si se encuentra y su cantidad es mayor a 1, la decrementa en 1.
  /// - Si el producto está marcado (`marcado == 1`), también decrementa el [totalShoppingPrice].
  /// - Si no se encuentra en esa lista, se ignora sin lanzar error.
  /// - Al final, se notifica a los listeners para refrescar la interfaz.
  void decrementQuantity(int productId) {
    groupedShopping.forEach((key, list) {
      try {
        final p = list.firstWhere((p) => p.productId == productId);
        if (p.quantity > 1) {
          p.quantity -= 1;
          if (p.marked == 1) {
            totalShoppingPrice -= p.price;
          }
        }
      } catch (e) {
        // NO SE ENCONTRO EL PRODUCTO, NO NECESITAMOS HACER NADA
      }
    });
    notifyListeners();
  }

  /// DESMARCA LOS PRODUCTOS Y PONE LAS CANTIDADES A 1
  Future<void> resetShoppingList() async {
    try {
      await database.rpc('resetear_productos_lista_compra', params: {
        'p_usuario_uuid': userId,
      });
      await loadShoppingList();
    } catch (e) {
      debugPrint('Error al resetear productos: $e');
    }
  }

  /// Elimina un producto de la compra en la base de datos y actualiza el estado local.
  ///
  /// Flujo principal:
  /// - Busca el producto en la lista local de [_shoppingList] a partir de su [productId].
  /// - Aplica una eliminación optimista mediante [deleteLocalProduct],
  ///   quitando el producto de la lista local antes de confirmar con la base de datos.
  /// - Intenta eliminar el registro en la tabla `compra` de la base de datos,
  ///   filtrando por `idproducto` y [userId].
  /// - Si la operación en la base de datos falla:
  ///   - Restaura el producto eliminado en la lista local con [addLocalProduct].
  ///   - Muestra un log del error y relanza la excepción para que el llamador la maneje.
  Future<void> deleteProduct(int productId) async {
    final deletedProduct = _shoppingList.firstWhere((p) => p.productId == productId);

    deleteLocalProduct(productId); // optimistic update

    try {
      await database
          .from('compra')
          .delete()
          .eq('idproducto', productId)
          .eq('usuariouuid', userId!);
    } catch (e) {
      addLocalProduct(deletedProduct);
      debugPrint("Error al eliminar producto: $e");
      rethrow;
    }
  }

  /// Elimina un producto de la lista local de compras (sin tocar la base de datos).
  ///
  /// Flujo principal:
  /// - Busca el producto en la lista principal de [_shoppingList] a partir de su [productId].
  /// - Si no existe, finaliza sin hacer nada.
  /// - Si existe:
  ///   - Lo elimina de la lista principal [_shoppingList].
  ///   - Lo elimina también de la lista agrupada [groupedShopping] por supermercado.
  ///   - Si el supermercado queda vacío, elimina la clave correspondiente del mapa.
  ///   - Si el producto estaba marcado, descuenta su precio total del [totalShoppingPrice].
  /// - Finalmente, notifica a los listeners para refrescar la interfaz.
  void deleteLocalProduct(int productId) {
    // BUSCAMOS EL INDICE Y GUARDAMOS EL PRODUCTO
    final index = _shoppingList.indexWhere((p) => p.productId == productId);
    if (index == -1) return;
    final productBackup = _shoppingList[index];

    // ELIMINAMOS LOCALMENTE DE LA LISTA PRINCIPAL
    _shoppingList.removeAt(index);

    // ELIMINAMOS DE LA LISTA AGRUPADA POR SUPERMERCADOS
    groupedShopping[productBackup.supermarket]
        ?.removeWhere((p) => p.productId == productId);

    // SI LA LISTA DEL SUPERMERCADO QUEDA VACIA, ELIMINAMOS LA CLAVE
    if (groupedShopping[productBackup.supermarket]?.isEmpty ?? false) {
      groupedShopping.remove(productBackup.supermarket);
    }

    // ACTUALIZAMOS EL TOTAL SI EL PRODUCTO ESTABA MARCADO
    if (productBackup.marked == 1) {
      totalShoppingPrice -= productBackup.price * productBackup.quantity;
    }

    notifyListeners();
  }

  /// Agrega un producto a la lista local de compras (sin tocar la base de datos).
  ///
  /// Flujo principal:
  /// - Inserta el producto en la lista principal [_shoppingList].
  /// - Ordena la lista completa mediante [sortShoppingList].
  /// - Inserta el producto también en la lista agrupada [groupedShopping] según su supermercado:
  ///   - Si no existe la clave del supermercado, la crea.
  ///   - Duplica la lista para forzar nueva referencia y refrescar la UI.
  /// - Si el producto está marcado, suma su precio al [totalShoppingPrice].
  /// - Finalmente, notifica a los listeners para refrescar la interfaz.
  void addLocalProduct(ShoppingListModel shoppingList) {
    _shoppingList.add(shoppingList);
    sortShoppingList(_shoppingList);

    groupedShopping = Map.from(groupedShopping);
    groupedShopping.putIfAbsent(shoppingList.supermarket, () => <ShoppingListModel>[]);
    groupedShopping[shoppingList.supermarket] = List<ShoppingListModel>.from(
      groupedShopping[shoppingList.supermarket]!,
    )..add(shoppingList);

    if (shoppingList.marked == 1) {
      totalShoppingPrice += shoppingList.price * shoppingList.quantity;
    }

    notifyListeners();
  }

  /// Actualiza el precio total al eliminar un producto de la compra y ajusta la lista agrupada.
  ///
  /// Flujo principal:
  /// - Resta del [totalShoppingPrice] el importe del producto eliminado (`precio * cantidad`).
  /// - Recorre las listas agrupadas por supermercado en [groupedShopping].
  ///   - Si encuentra el producto, lo elimina de la lista correspondiente.
  ///   - Si tras la eliminación la lista queda vacía, marca el supermercado para ser eliminado.
  /// - Si algún supermercado queda vacío, elimina la clave del mapa.
  /// - Finalmente, notifica a los listeners para refrescar la interfaz.
  void updatePrice(int productId, double price, int quantity) {
    // RESTAMOS EL PRECIO DEL PRODUCTO ELIMINADO
    totalShoppingPrice -= price * quantity;

    String? supermarketToDelete;

    groupedShopping.forEach((supermarket, list) {
      final pIndex = list.indexWhere((p) => p.productId == productId);
      if (pIndex != -1) {
        list.removeAt(pIndex);
        if (list.isEmpty) {
          supermarketToDelete =
              supermarket;
        }
      }
    });
    // SI EL SUPERMERCADO QUEDA VACIO, LO ELIMINAMOS
    if (supermarketToDelete != null) {
      groupedShopping.remove(supermarketToDelete);
    }

    notifyListeners();
  }

  /// Agrega un producto a la tabla `compra` en la base de datos y a la lista local.
  ///
  /// Flujo principal:
  /// - Consulta en la base de datos si el producto ya existe en la tabla `compra`
  ///   filtrando por [productId] y [userId].
  /// - Si el producto ya está en la compra, lanza una [DuplicateProductException].
  /// - Si no existe:
  ///   - Inserta un nuevo registro en la base de datos con los datos del producto.
  ///   - Crea una instancia local de [ShoppingListModel] con cantidad inicial = 1 y marcado = 0.
  ///   - Lo agrega a la lista principal [_shoppingList].
  ///   - Lo agrega también a la lista agrupada [groupedShopping] según su supermercado.
  /// - Finalmente, notifica a los listeners para refrescar la interfaz.
  Future<void> addToShoppingList(int productId, double price, String name, String supermarket) async {
    try {
      final existingProducts = await database
          .from('compra')
          .select()
          .eq('idproducto', productId)
          .eq('usuariouuid', userId!);

      if (existingProducts.isNotEmpty) {
        throw DuplicateProductException();
      }

      await database.from('compra').insert({
        'idproducto': productId,
        'nombre': name,
        'precio': price,
        'marcado': 0,
        'usuariouuid': userId,
      });

      final newProduct = ShoppingListModel(
        productId: productId,
        name: name,
        price: price,
        quantity: 1,
        marked: 0,
        userUuid: userId!,
        supermarket: supermarket, // ESTE ATRIBUTO SOLO ESTA EN EL MODELO LOCAL
      );

      _shoppingList.add(newProduct);
      groupedShopping = Map.from(groupedShopping)
        ..putIfAbsent(supermarket, () => [])
        ..[supermarket]!.add(newProduct);

    notifyListeners();
    } on DuplicateProductException {
    rethrow;
    } catch (e) {
    debugPrint("Error agregando producto a la compra: $e");
    rethrow;
    }
  }

  /// Actualiza la información de un producto en la lista local de compras.
  ///
  /// Flujo principal:
  /// - Busca en la lista principal [_shoppingList] el producto cuyo [productId] coincida
  ///   con el del [updatedProduct].
  /// - Si no existe, termina sin hacer nada.
  /// - Si existe:
  ///   - Crea una nueva instancia de [ShoppingListModel] con los datos actualizados
  ///     (nombre, precio, supermercado), manteniendo la cantidad y marcado previos.
  ///   - Reemplaza el producto en la lista principal [_shoppingList].
  ///   - Elimina la versión anterior de [groupedShopping].
  ///   - Si el supermercado antiguo queda vacío, elimina su clave del mapa.
  ///   - Inserta el producto actualizado en la lista agrupada correspondiente a su nuevo supermercado.
  ///   - Ordena las compras mediante [sortShoppingList].
  /// - Finalmente, notifica a los listeners para refrescar la interfaz.
  void updateLocalProduct(ProductModel updatedProduct) {
    final index =
    _shoppingList.indexWhere((c) => c.productId == updatedProduct.id);
    if (index == -1) return;

    final existingShopping = _shoppingList[index];

    final updatedShopping = ShoppingListModel(
      productId: existingShopping.productId,
      quantity: existingShopping.quantity,
      marked: existingShopping.marked,
      userUuid: existingShopping.userUuid,
      supermarket: updatedProduct.supermarket,
      name: updatedProduct.name,
      price: updatedProduct.price,
    );

    _shoppingList[index] = updatedShopping;

    groupedShopping[existingShopping.supermarket]
        ?.removeWhere((c) => c.productId == existingShopping.productId);

    if (groupedShopping[existingShopping.supermarket]?.isEmpty ?? false) {
      groupedShopping.remove(existingShopping.supermarket);
    }

    groupedShopping.putIfAbsent(updatedShopping.supermarket, () => []);
    groupedShopping[updatedShopping.supermarket]!.add(updatedShopping);

    sortShoppingList(shoppingList);

    notifyListeners();
  }

  /// METODO PARA ORDENAR ALFABETICAMENTE
  List<ShoppingListModel> sortShoppingList(List<ShoppingListModel> shoppingList) {
    shoppingList.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    for (var list in groupedShopping.values) {
      list.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return shoppingList;
  }


  /// Metodo para generar la lista de la compra en formato String
  ///
  /// Flujo principal:
  /// - Comprueba si hay productos marcados, si no hay, devuelve una cadena vacía para mostrar una alerta.
  /// - Si es escritorio (Windows/Linux/macOS): copia el texto al portapapeles y muestra snackbar de éxito.
  /// - Si es móvil (Android/iOS): intenta abrir WhatsApp con `https://wa.me/?text=...`.
  ///   - Si no se puede abrir, usa el diálogo de compartir genérico (`Share.share`).
  /// - Si ocurre cualquier error, muestra un snackbar de error y finaliza.
  String generateShoppingListMessage(context, Locale locale) {
    final hasMarked = groupedShopping.values
        .any((list) => list.any((product) => product.marked == 1));

    if (!hasMarked) return '';

    final buffer = StringBuffer();
    buffer.writeln('---- ${AppLocalizations.of(context)!.shopping_list} ----');
    buffer.writeln('');

    groupedShopping.forEach((supermarket, products) {

      final markedProducts = products.where((product) => product.marked == 1).toList();
      if (markedProducts.isEmpty) return;

      buffer.writeln(supermarket);
      for (final p in markedProducts) {
        final pricePerUnit = NumberFormat.currency(locale:locale.toString(), symbol: '€')
            .format(p.price);
        final totalPrice = NumberFormat.currency(locale:locale.toString(), symbol: '€')
            .format(p.price * p.quantity);

        buffer.writeln(
            ' [ ] • ${p.name} — $pricePerUnit/u × ${p.quantity} = $totalPrice');
      }
      buffer.writeln('');
    });

    final totalFormattedPrice =
    NumberFormat.currency(locale: locale.toString(), symbol: '€').format(totalShoppingPrice);
    buffer.writeln('Total: $totalFormattedPrice');

    return buffer.toString();
  }

  /// Método para eliminar los productos marcados de la lista de la compra.
  ///
  /// Flujo principal:
  /// - Filtramos los productos marcados (producto.marcado == 1)
  /// - Eliminamos de la lista local y notificamos a los constructores para que lo vea instantáneo el usuario
  /// - Luego elimina esos mismos productos de la base de datos en Supabase.
  /// - Actualizamos la lista de la compra
  /// - Si ocurre algún error durante el proceso, lo captura, lo muestra en consola y relanza la excepción.
  Future<void> deleteMarkedProducts() async {
    try {
      final markedProducts = _shoppingList.where((product) => product.marked == 1).toList();

      _shoppingList.removeWhere((p) => p.marked == 1);
      notifyListeners();

      for (var product in markedProducts) {
        await database
            .from('compra')
            .delete()
            .eq('idproducto', product.productId)
            .eq('usuariouuid', userId!);
      }

      // ACTUALIZAMOS LA LISTA DE LA COMPRA
      groupedShopping = {};
      for (var shoppingList in _shoppingList) {
        groupedShopping.putIfAbsent(shoppingList.supermarket, () => []);
        groupedShopping[shoppingList.supermarket]!.add(shoppingList);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error al eliminar productos marcados: $e');
      rethrow;
    }
  }

}
