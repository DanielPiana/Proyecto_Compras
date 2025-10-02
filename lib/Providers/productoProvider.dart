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

  /// Obtiene los productos agrupados por supermercado.
  ///
  /// Flujo principal:
  /// - Recorre la lista interna de productos [_productos].
  /// - Agrupa cada producto según su supermercado (si no tiene, se asigna "Sin supermercado").
  /// - Normaliza el nombre del supermercado (primera letra mayúscula, resto minúsculas).
  /// - Ordena los productos alfabéticamente dentro de cada supermercado.
  /// - Ordena también los supermercados alfabéticamente por nombre.
  ///
  /// Retorna:
  /// - [Map<String, List<ProductoModel>>]: Un mapa donde la clave es el nombre del supermercado
  ///   y el valor es la lista de productos correspondientes, ambos ordenados.
  ///
  /// Excepciones:
  /// - No lanza excepciones.
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

  /// METODO PARA ESTABLECER UN USUARIO Y RECARGAR SUS PRODUCTOS
  Future<void> setUserAndReload(String? uid) async {
    userId = uid;
    await cargarProductos();
  }

  /// Carga los productos del usuario desde la base de datos.
  ///
  /// Flujo principal:
  /// - Verifica si existe un [userId] válido; si no lo hay, limpia la lista de productos y notifica a los listeners.
  /// - Consulta la tabla `productos` en la base de datos, filtrando por el [userId].
  /// - Convierte los resultados en una lista de [ProductoModel].
  /// - Ordena los productos mediante [ordenarProductos].
  /// - Notifica a los listeners para actualizar la UI.
  ///
  /// Retorna:
  /// - `void` (no retorna nada)
  /// Excepciones:
  /// - Puede lanzar errores si falla la consulta a la base de datos o la conversión de datos.
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

  /// Obtiene los productos del usuario desde la base de datos.
  ///
  /// Flujo principal:
  /// - Consulta la tabla `productos` en la base de datos, filtrando por el [userId].
  /// - Convierte el resultado en una lista de instancias de [ProductoModel].
  /// - Si ocurre un error durante la consulta o la conversión, se captura la excepción,
  ///   se imprime un log de error y se retorna una lista vacía.
  ///
  /// Retorna:
  /// - [Future<List<ProductoModel>>]: Una lista de productos obtenidos de la base de datos.
  ///   Si ocurre un error, retorna una lista vacía.
  ///
  /// Excepciones:
  /// - Puede lanzar errores relacionados con la consulta a la base de datos,
  ///   aunque son capturados y gestionados internamente.
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


  /// METODO PARA ORDENAR PRODUCTOS ALFABETICAMENTE
  List<ProductoModel> ordenarProductos(List<ProductoModel> productos) {

    productos.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    return productos;
  }


  /// Crea un nuevo producto en la base de datos y lo añade a la lista local.
  ///
  /// Flujo principal:
  /// - Realiza una copia de respaldo de la lista local de productos.
  /// - Inserta el [nuevoProducto] en la tabla `productos` de la base de datos.
  /// - Si la inserción devuelve un resultado, reemplaza el producto temporal en la lista local
  ///   con la versión creada desde la base de datos (incluyendo su ID generado).
  /// - Ordena los productos y notifica a los listeners para actualizar la UI.
  /// - Si ocurre un error, restaura la lista local desde la copia de respaldo,
  ///   notifica a los listeners y relanza la excepción.
  ///
  /// Parámetros:
  /// - [nuevoProducto]: Instancia de [ProductoModel] que se desea crear.
  ///
  /// Retorna:
  /// - `Future<void>` (no retorna datos, solo una operación asincrónica).
  ///
  /// Excepciones:
  /// - Puede lanzar errores si falla la inserción en la base de datos.
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


  /// Actualiza un producto existente en la base de datos y en la lista local.
  ///
  /// Flujo principal:
  /// - Realiza una copia de respaldo de la lista local de productos.
  /// - Busca el producto en la lista local y lo reemplaza por la versión actualizada.
  /// - Ordena los productos y notifica a los listeners para refrescar la UI.
  /// - Actualiza también el producto en el [CompraProvider] para mantener la coherencia local.
  /// - Intenta actualizar el producto en la tabla `productos` de la base de datos.
  /// - Actualiza en paralelo los registros de la tabla `compra` relacionados con ese producto.
  /// - Si ocurre un error, restaura la lista local desde el respaldo,
  ///   notifica a los listeners y relanza la excepción.
  ///
  /// Parámetros:
  /// - [productoActualizado]: Instancia de [ProductoModel] con los nuevos datos.
  /// - [compraProvider]: Proveedor de compras, usado para mantener consistencia local.
  ///
  /// Retorna:
  /// - `Future<void>` (no retorna datos, solo una operación asincrónica).
  ///
  /// Excepciones:
  /// - Puede lanzar errores si falla la actualización en la base de datos.
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


  /// Elimina un producto de la base de datos y de la lista local.
  ///
  /// Flujo principal:
  /// - Realiza una copia de respaldo de la lista local de productos.
  /// - Elimina el producto de la lista local según su [id].
  /// - Elimina también el producto en el [CompraProvider] para mantener coherencia local.
  /// - Notifica a los listeners para refrescar la UI.
  /// - Intenta eliminar el producto en la tabla `productos` de la base de datos.
  /// - Si ocurre un error, restaura la lista local desde el respaldo,
  ///   vuelve a ordenar los productos, notifica a los listeners y relanza la excepción.
  ///
  /// Parámetros:
  /// - [context]: Contexto de la aplicación, usado para acceder al [CompraProvider].
  /// - [id]: Identificador del producto a eliminar.
  ///
  /// Retorna:
  /// - `void` (no retorna nada).
  ///
  /// Excepciones:
  /// - Puede lanzar errores si falla la eliminación en la base de datos.
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


  /// Obtiene la lista de supermercados asociados a los productos del usuario.
  ///
  /// Flujo principal:
  /// - Si existen productos cargados en la lista local, devuelve los supermercados únicos
  ///   presentes en dichos productos (ignorando los vacíos).
  /// - Si no hay productos cargados, consulta la tabla `productos` en la base de datos,
  ///   filtrando por el [userId], y extrae los supermercados únicos.
  ///
  /// Retorna:
  /// - [Future<List<String>>]: Una lista con los nombres de supermercados únicos.
  ///   La lista nunca contendrá cadenas vacías, pero puede estar vacía si no hay supermercados.
  ///
  /// Excepciones:
  /// - Puede lanzar errores si falla la consulta a la base de datos.
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

  /// METODO PARA AÑADIR UN PRODUCTO A LA LISTA LOCAL Y NOTIFICAR A LOS CONSTRUCTORES
  void addProductoLocal(ProductoModel producto) {
    _productos.add(producto);
    notifyListeners();
  }

  /// METODO PARA ELIMINAR UN PRODUCTO DE LA LISTA LOCAL Y NOTIFICAR A LOS CONSTRUCTORES
  void removeProductoLocal(int idProducto) {
    _productos.removeWhere((p) => p.id == idProducto);
    notifyListeners();
  }

  /// METODO PARA ACTUALIZAR UN PRODUCTO DE LA LISTA LOCAL Y NOTIFICAR A LOS CONSTRUCTORES
  void updateProductoLocal(int index, ProductoModel productoActualizado) {
    if (index >= 0 && index < _productos.length) {
      _productos[index] = productoActualizado;
      notifyListeners();
    }
  }

}
