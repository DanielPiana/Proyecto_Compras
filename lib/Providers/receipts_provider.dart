import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:proyectocompras/models/shopping_list_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/receipt_model.dart';
import '../models/product_receipt_model.dart';
import '../utils/text_normalizer.dart';


class ReceiptProvider extends ChangeNotifier {
  final SupabaseClient database;
  String? userId;

  List<ReceiptModel> _receipts = [];
  List<ReceiptModel> get receipts => _receipts;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ReceiptModel> filteredReceipts = [];
  String lastQuery = '';

  // GETTER PARA MOSTRAR FACTURAS
  List<ReceiptModel> get receiptsToShow {
    if (filteredReceipts.isEmpty && lastQuery.trim().isEmpty) {
      return _receipts;
    }
    return filteredReceipts;
  }

  void setSearchText(String value) {
    lastQuery = value;

    if (value.trim().isEmpty) {
      filteredReceipts = [];
      notifyListeners();
      return;
    }

    final query = normalizeText(value);


    final monthsMap = {
      'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
      'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
      'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12'
    };

    // COMPROBAR SI LA BUSQUEDA DEL USUARIO COINCIDE CON ALGUN NOMBRE DE MES
    String? monthNumber;
    for (var entry in monthsMap.entries) {
      if (entry.key.contains(query)) {
        monthNumber = entry.value;
        break;
      }
    }

    filteredReceipts = _receipts.where((receipt) {
      final date = normalizeText(receipt.date);

      // BUSQUEDA DIRECTA DE NÚMERO
      if (date.contains(query)) return true;

      // SI LA BUSQUEDA COINCIDE CON UN MES, BUSCAMOS POR SU NUMERO
      if (monthNumber != null && receipt.date.contains('/$monthNumber/')) {
        return true;
      }

      // BUSQUEDA POR NOMBRES DE PRODUCTO
      final hasMatchingProduct = receipt.products.any((products) {
        final productName = normalizeText(products.name);
        return productName.contains(query);
      });

      return hasMatchingProduct;
    }).toList();

    notifyListeners();
  }

  ReceiptProvider(this.database, this.userId);

  /// METODO PARA ESTABLECER UN USUARIO Y RECARGAR SUS PRODUCTOS
  Future<void> setUserAndReload(String? uuid) async {
    userId = uuid;
    if (uuid == null) {
      _receipts = [];
      notifyListeners();
      return;
    }
    await loadReceipts();
  }

  /// Genera una factura a partir de los productos marcados de la lista de la compra
  ///
  /// Flujo principal:
  /// - Recalcula el precio total de los productos marcados
  /// - Intenta insertar la fecha en la base de datos
  /// - Recuperamos el id de la factura que acabamos de insertar
  /// e insertamos en producto_factura todos los productos relacionados
  /// con el id de la factura asociado
  /// Creamos el modelo de [ReceiptModel]
  /// Lo insertamos en la lista local y notificamos a los listeners
  Future<void> generateReceipt(List<ShoppingListModel> selectedProducts, String userUuid,) async {
    try {
      final double totalPrice = selectedProducts.fold(
        0.0,
            (sum, product) => sum + product.price * product.quantity,
      );

      final currentDate = DateFormat("dd/MM/yyyy").format(DateTime.now());

      final insertedReceipt = await database.from('facturas').insert({
        'precio': totalPrice,
        'fecha': currentDate,
        'usuariouuid': userUuid,
      }).select().single();

      final receiptId = insertedReceipt['id'];

      for (var product in selectedProducts) {
        await database.from('producto_factura').insert({
          'idproducto': product.productId,
          'idfactura': receiptId,
          'cantidad': product.quantity,
          'preciounidad': product.price,
          'total': product.price * product.quantity,
          'usuariouuid': userUuid,
        });
      }

      final newReceipt = ReceiptModel(
        id: receiptId,
        price: totalPrice,
        date: currentDate,
        userUuid: userUuid,
        products: selectedProducts.map((p) {
          return ProductReceiptModel(
            name: p.name,
            quantity: p.quantity,
            unitPrice: p.price,
          );
        }).toList(),
      );

      _receipts.insert(0, newReceipt);
      notifyListeners();
    } catch (e) {
      debugPrint('Error al generar factura: $e');
      rethrow;
    }
  }

  /// Carga las facturas del usuario desde la base de datos
  ///
  /// Flujo principal:
  /// - Consulta la tabla 'facturas' en la base de datos, filtrando por [userId]
  /// - Convierte los resultados en una lista de [ReceiptModel]
  /// - Notifica a los listeners para actualizar la UI
  Future<void> loadReceipts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final receiptsData = await database
          .from('facturas')
          .select()
          .eq('usuariouuid', userId!)
          .order('id', ascending: false);

      final List<ReceiptModel> loadedReceipts = [];

      for (var receipt in receiptsData) {
        final receiptId = receipt['id'];

        final productsData = await database
            .from('producto_factura')
            .select('cantidad, preciounidad, productos(nombre)')
            .eq('idfactura', receiptId);

        final productsList = (productsData as List).map((item) {
          return ProductReceiptModel.fromMap(item);
        }).toList();

        loadedReceipts.add(
          ReceiptModel(
            id: receipt['id'],
            price: (receipt['precio'] as num).toDouble(),
            date: receipt['fecha'].toString(),
            userUuid: receipt['usuariouuid'],
            products: productsList,
          ),
        );
      }

      _receipts = loadedReceipts;
    } catch (e) {
      debugPrint('Error al cargar facturas: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elimina una factura de la base de datos y sus productos relacionados
  /// de la tabla 'producto_factura'
  /// Flujo principal:
  /// Realizamos una copia de seguridad de la lista local de facturas
  /// Eliminamos la factura de la lista local y notificamos a los listeners
  /// Eliminamos los productos asociados a esa factura de la tabla 'producto_factura'
  /// Eliminamos la factura de la base de datos, si da un error, volvemos a
  /// insertar la factura en la lista local y notificamos a los listeners
  Future<void> deleteReceipt(int receiptId, String userUuid) async {

    final backup = List<ReceiptModel>.from(receipts);

    receipts.removeWhere((f) => f.id == receiptId);
    notifyListeners();

    try {
      await database.from('producto_factura').delete().eq('idfactura', receiptId);

      await database
          .from('facturas')
          .delete()
          .eq('id', receiptId)
          .eq('usuariouuid', userUuid);
    } catch (e) {
      debugPrint('Error al borrar factura: $e');
      _receipts = backup;
      notifyListeners();
      rethrow;
    }
  }

}