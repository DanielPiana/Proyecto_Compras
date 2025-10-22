import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/compraModel.dart';
import '../models/productoModel.dart';
import 'package:intl/intl.dart';


class DuplicateProductException implements Exception {}

class CompraProvider extends ChangeNotifier {
  final SupabaseClient database;
  String? userId;

  // LISTA DE COMPRAS CARGADAS DESDE LA BASE DE DATOS
  List<CompraModel> _compras = [];
  List<CompraModel> get compras => _compras;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // LISTA AGRUPADA POR SUPERMERCADO
  Map<String, List<CompraModel>> comprasAgrupadas = {};
  double precioTotalCompra = 0.0;

  CompraProvider(this.database, this.userId);

  /// METODO PARA MARCAR O DESMARCAR UN PRODUCTO
  void alternarMarcado(CompraModel producto) {
    producto.marcado = producto.marcado == 1 ? 0 : 1;

    //ACTUALIZAMOS EL PRECIO TOTAL
    if (producto.marcado == 1) {
      precioTotalCompra += producto.precio * producto.cantidad;
    } else {
      precioTotalCompra -= producto.precio * producto.cantidad;
    }
    notifyListeners();
  }

  /// METODO PARA ESTABLECER EL USUARIO Y CARGAR SUS DATOS
  Future<void> setUserAndReload(String? uuid) async {
    userId = uuid;
    if (uuid == null) {
      _compras = [];
      notifyListeners();
      return;
    }
    await cargarCompra();
  }

  /// Carga la lista de compras del usuario desde la base de datos y actualiza el estado local.
  ///
  /// Flujo principal:
  /// - Consulta la tabla `compra` en la base de datos, incluyendo la relación con `productos(supermercado)`,
  ///   filtrando por el [userId].
  /// - Inicializa las estructuras locales (`_compras`, `comprasAgrupadas`, `precioTotalCompra`).
  /// - Convierte los resultados en instancias de [CompraModel] y los guarda en la lista local.
  /// - Ordena las compras mediante [ordenarCompras].
  /// - Agrupa las compras por supermercado, asegurando nueva referencia del `Map` en cada iteración
  ///   para forzar la recarga en la UI.
  /// - Calcula el precio total de la compra sumando los productos marcados.
  /// - Notifica a los listeners para refrescar la interfaz.
  Future<void> cargarCompra() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await database
          .from('compra')
          .select('*, productos(supermercado)')
          .eq('usuariouuid', userId!);

      final List productos = response as List;

      _compras = [];
      comprasAgrupadas = {};
      precioTotalCompra = 0.0;

      // Construimos la lista local
      for (var p in productos) {
        final compra = CompraModel.fromMap(p);
        _compras.add(compra);
      }

      ordenarCompras(_compras);

      // Agrupamos por supermercado
      for (var compra in _compras) {
        final supermercado = compra.supermercado;

        comprasAgrupadas = Map.from(comprasAgrupadas)
          ..putIfAbsent(supermercado, () => [])
          ..[supermercado]!.add(compra);

        if (compra.marcado == 1) {
          precioTotalCompra += compra.precio * compra.cantidad;
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
  /// - Recorre todas las listas agrupadas por supermercado en [comprasAgrupadas].
  /// - Busca el producto cuyo [idProducto] coincida.
  /// - Si se encuentra, incrementa su cantidad en 1.
  /// - Si el producto está marcado (`marcado == 1`), también incrementa el [precioTotalCompra].
  /// - Si no se encuentra en esa lista, se ignora sin lanzar error.
  /// - Al final, se notifica a los listeners para refrescar la interfaz.
  void sumar1Cantidad(int idProducto) {
    comprasAgrupadas.forEach((key, list) {
      try {
        final p = list.firstWhere((p) => p.idProducto == idProducto);
        p.cantidad += 1;
        if (p.marcado == 1) {
          precioTotalCompra += p.precio;
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
  /// - Recorre todas las listas agrupadas por supermercado en [comprasAgrupadas].
  /// - Busca el producto cuyo [idProducto] coincida.
  /// - Si se encuentra y su cantidad es mayor a 1, la decrementa en 1.
  /// - Si el producto está marcado (`marcado == 1`), también decrementa el [precioTotalCompra].
  /// - Si no se encuentra en esa lista, se ignora sin lanzar error.
  /// - Al final, se notifica a los listeners para refrescar la interfaz.
  void restar1Cantidad(int idProducto) {
    comprasAgrupadas.forEach((key, list) {
      try {
        final p = list.firstWhere((p) => p.idProducto == idProducto);
        if (p.cantidad > 1) {
          p.cantidad -= 1;
          if (p.marcado == 1) {
            precioTotalCompra -= p.precio;
          }
        }
      } catch (e) {
        // NO SE ENCONTRO EL PRODUCTO, NO NECESITAMOS HACER NADA
      }
    });
    notifyListeners();
  }

  /// DESMARCA LOS PRODUCTOS Y PONE LAS CANTIDADES A 1
  Future<void> resetearProductosListaCompra() async {
    try {
      await database.rpc('resetear_productos_lista_compra', params: {
        'p_usuario_uuid': userId,
      });
      await cargarCompra();
    } catch (e) {
      debugPrint('Error al resetear productos: $e');
    }
  }

  /// Elimina un producto de la compra en la base de datos y actualiza el estado local.
  ///
  /// Flujo principal:
  /// - Busca el producto en la lista local de [_compras] a partir de su [idProducto].
  /// - Aplica una eliminación optimista mediante [eliminarProductoLocal],
  ///   quitando el producto de la lista local antes de confirmar con la base de datos.
  /// - Intenta eliminar el registro en la tabla `compra` de la base de datos,
  ///   filtrando por `idproducto` y [userId].
  /// - Si la operación en la base de datos falla:
  ///   - Restaura el producto eliminado en la lista local con [addProductoLocal].
  ///   - Muestra un log del error y relanza la excepción para que el llamador la maneje.
  Future<void> deleteProducto(int idProducto) async {
    final eliminado = _compras.firstWhere((p) => p.idProducto == idProducto);

    eliminarProductoLocal(idProducto); // optimistic update

    try {
      await database
          .from('compra')
          .delete()
          .eq('idproducto', idProducto)
          .eq('usuariouuid', userId!);
    } catch (e) {
      addProductoLocal(eliminado);
      debugPrint("Error al eliminar producto: $e");
      rethrow;
    }
  }

  /// Elimina un producto de la lista local de compras (sin tocar la base de datos).
  ///
  /// Flujo principal:
  /// - Busca el producto en la lista principal de [_compras] a partir de su [idProducto].
  /// - Si no existe, finaliza sin hacer nada.
  /// - Si existe:
  ///   - Lo elimina de la lista principal [_compras].
  ///   - Lo elimina también de la lista agrupada [comprasAgrupadas] por supermercado.
  ///   - Si el supermercado queda vacío, elimina la clave correspondiente del mapa.
  ///   - Si el producto estaba marcado, descuenta su precio total del [precioTotalCompra].
  /// - Finalmente, notifica a los listeners para refrescar la interfaz.
  void eliminarProductoLocal(int idProducto) {
    // BUSCAMOS EL INDICE Y GUARDAMOS EL PRODUCTO
    final index = _compras.indexWhere((p) => p.idProducto == idProducto);
    if (index == -1) return;
    final productoBackup = _compras[index];

    // ELIMINAMOS LOCALMENTE DE LA LISTA PRINCIPAL
    _compras.removeAt(index);

    // ELIMINAMOS DE LA LISTA AGRUPADA POR SUPERMERCADOS
    comprasAgrupadas[productoBackup.supermercado]
        ?.removeWhere((p) => p.idProducto == idProducto);

    // SI LA LISTA DEL SUPERMERCADO QUEDA VACIA, ELIMINAMOS LA CLAVE
    if (comprasAgrupadas[productoBackup.supermercado]?.isEmpty ?? false) {
      comprasAgrupadas.remove(productoBackup.supermercado);
    }

    // ACTUALIZAMOS EL TOTAL SI EL PRODUCTO ESTABA MARCADO
    if (productoBackup.marcado == 1) {
      precioTotalCompra -= productoBackup.precio * productoBackup.cantidad;
    }

    notifyListeners();
  }

  /// Agrega un producto a la lista local de compras (sin tocar la base de datos).
  ///
  /// Flujo principal:
  /// - Inserta el producto en la lista principal [_compras].
  /// - Ordena la lista completa mediante [ordenarCompras].
  /// - Inserta el producto también en la lista agrupada [comprasAgrupadas] según su supermercado:
  ///   - Si no existe la clave del supermercado, la crea.
  ///   - Duplica la lista para forzar nueva referencia y refrescar la UI.
  /// - Si el producto está marcado, suma su precio al [precioTotalCompra].
  /// - Finalmente, notifica a los listeners para refrescar la interfaz.
  void addProductoLocal(CompraModel compra) {
    _compras.add(compra);
    ordenarCompras(_compras);

    comprasAgrupadas = Map.from(comprasAgrupadas);
    comprasAgrupadas.putIfAbsent(compra.supermercado, () => <CompraModel>[]);
    comprasAgrupadas[compra.supermercado] = List<CompraModel>.from(
      comprasAgrupadas[compra.supermercado]!,
    )..add(compra);

    if (compra.marcado == 1) {
      precioTotalCompra += compra.precio * compra.cantidad;
    }

    notifyListeners();
  }

  /// Actualiza el precio total al eliminar un producto de la compra y ajusta la lista agrupada.
  ///
  /// Flujo principal:
  /// - Resta del [precioTotalCompra] el importe del producto eliminado (`precio * cantidad`).
  /// - Recorre las listas agrupadas por supermercado en [comprasAgrupadas].
  ///   - Si encuentra el producto, lo elimina de la lista correspondiente.
  ///   - Si tras la eliminación la lista queda vacía, marca el supermercado para ser eliminado.
  /// - Si algún supermercado queda vacío, elimina la clave del mapa.
  /// - Finalmente, notifica a los listeners para refrescar la interfaz.
  void actualizarPrecio(int idProducto, double precio, int cantidad) {
    // RESTAMOS EL PRECIO DEL PRODUCTO ELIMINADO
    precioTotalCompra -= precio * cantidad;

    String? supermercadoAEliminar;

    comprasAgrupadas.forEach((supermercado, lista) {
      final pIndex = lista.indexWhere((p) => p.idProducto == idProducto);
      if (pIndex != -1) {
        lista.removeAt(pIndex);
        if (lista.isEmpty) {
          supermercadoAEliminar =
              supermercado;
        }
      }
    });
    // SI EL SUPERMERCADO QUEDA VACIO, LO ELIMINAMOS
    if (supermercadoAEliminar != null) {
      comprasAgrupadas.remove(supermercadoAEliminar);
    }

    notifyListeners();
  }

  /// Agrega un producto a la tabla `compra` en la base de datos y a la lista local.
  ///
  /// Flujo principal:
  /// - Consulta en la base de datos si el producto ya existe en la tabla `compra`
  ///   filtrando por [idProducto] y [userId].
  /// - Si el producto ya está en la compra, lanza una [DuplicateProductException].
  /// - Si no existe:
  ///   - Inserta un nuevo registro en la base de datos con los datos del producto.
  ///   - Crea una instancia local de [CompraModel] con cantidad inicial = 1 y marcado = 0.
  ///   - Lo agrega a la lista principal [_compras].
  ///   - Lo agrega también a la lista agrupada [comprasAgrupadas] según su supermercado.
  /// - Finalmente, notifica a los listeners para refrescar la interfaz.
  Future<void> agregarACompra(int idProducto, double precio, String nombre, String supermercado,) async {
    try {
      final productosExistentes = await database
          .from('compra')
          .select()
          .eq('idproducto', idProducto)
          .eq('usuariouuid', userId!);

      if (productosExistentes.isNotEmpty) {
        throw DuplicateProductException();
      }

      await database.from('compra').insert({
        'idproducto': idProducto,
        'nombre': nombre,
        'precio': precio,
        'marcado': 0,
        'usuariouuid': userId,
      });

      final nuevoProducto = CompraModel(
        idProducto: idProducto,
        nombre: nombre,
        precio: precio,
        cantidad: 1,
        marcado: 0,
        usuarioUuid: userId!,
        supermercado: supermercado, // ESTE ATRIBUTO SOLO ESTA EN EL MODELO LOCAL
      );

      _compras.add(nuevoProducto);
      comprasAgrupadas = Map.from(comprasAgrupadas)
        ..putIfAbsent(supermercado, () => [])
        ..[supermercado]!.add(nuevoProducto);

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
  /// - Busca en la lista principal [_compras] el producto cuyo [idProducto] coincida
  ///   con el del [productoActualizado].
  /// - Si no existe, termina sin hacer nada.
  /// - Si existe:
  ///   - Crea una nueva instancia de [CompraModel] con los datos actualizados
  ///     (nombre, precio, supermercado), manteniendo la cantidad y marcado previos.
  ///   - Reemplaza el producto en la lista principal [_compras].
  ///   - Elimina la versión anterior de [comprasAgrupadas].
  ///   - Si el supermercado antiguo queda vacío, elimina su clave del mapa.
  ///   - Inserta el producto actualizado en la lista agrupada correspondiente a su nuevo supermercado.
  ///   - Ordena las compras mediante [ordenarCompras].
  /// - Finalmente, notifica a los listeners para refrescar la interfaz.
  void actualizarProductoEnCompraLocal(ProductoModel productoActualizado) {
    final index =
    _compras.indexWhere((c) => c.idProducto == productoActualizado.id);
    if (index == -1) return;

    final compraExistente = _compras[index];

    final compraActualizada = CompraModel(
      idProducto: compraExistente.idProducto,
      cantidad: compraExistente.cantidad,
      marcado: compraExistente.marcado,
      usuarioUuid: compraExistente.usuarioUuid,
      supermercado: productoActualizado.supermercado,
      nombre: productoActualizado.nombre,
      precio: productoActualizado.precio,
    );

    _compras[index] = compraActualizada;

    comprasAgrupadas[compraExistente.supermercado]
        ?.removeWhere((c) => c.idProducto == compraExistente.idProducto);

    if (comprasAgrupadas[compraExistente.supermercado]?.isEmpty ?? false) {
      comprasAgrupadas.remove(compraExistente.supermercado);
    }

    comprasAgrupadas.putIfAbsent(compraActualizada.supermercado, () => []);
    comprasAgrupadas[compraActualizada.supermercado]!.add(compraActualizada);

    ordenarCompras(compras);

    notifyListeners();
  }

  /// METODO PARA ORDENAR ALFABETICAMENTE
  List<CompraModel> ordenarCompras(List<CompraModel> compras) {
    compras.sort(
            (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    for (var lista in comprasAgrupadas.values) {
      lista.sort(
              (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    }

    return compras;
  }


  /// Metodo para generar la lista de la compra en formato String
  ///
  /// Flujo principal:
  /// - Comprueba si hay productos marcados, si no hay, devuelve una cadena vacía para mostrar una alerta.
  /// - Si es escritorio (Windows/Linux/macOS): copia el texto al portapapeles y muestra snackbar de éxito.
  /// - Si es móvil (Android/iOS): intenta abrir WhatsApp con `https://wa.me/?text=...`.
  ///   - Si no se puede abrir, usa el diálogo de compartir genérico (`Share.share`).
  /// - Si ocurre cualquier error, muestra un snackbar de error y finaliza.
  String generarMensajeListaCompra(context, Locale locale) {
    final hayMarcados = comprasAgrupadas.values
        .any((lista) => lista.any((producto) => producto.marcado == 1));

    if (!hayMarcados) return '';

    final buffer = StringBuffer();
    buffer.writeln('---- ${AppLocalizations.of(context)!.shopping_list} ----');
    buffer.writeln('');

    comprasAgrupadas.forEach((supermercado, productos) {

      final productosMarcados = productos.where((producto) => producto.marcado == 1).toList();
      if (productosMarcados.isEmpty) return;

      buffer.writeln(supermercado);
      for (final p in productosMarcados) {
        final precioUnidad = NumberFormat.currency(locale:locale.toString(), symbol: '€')
            .format(p.precio);
        final precioTotal = NumberFormat.currency(locale:locale.toString(), symbol: '€')
            .format(p.precio * p.cantidad);

        buffer.writeln(
            ' [ ] • ${p.nombre} — $precioUnidad/u × ${p.cantidad} = $precioTotal');
      }
      buffer.writeln('');
    });

    final totalFormateado =
    NumberFormat.currency(locale: locale.toString(), symbol: '€').format(precioTotalCompra);
    buffer.writeln('Total: $totalFormateado');

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

  Future<void> eliminarProductosMarcados() async {
    try {
      final productosMarcados = _compras.where((producto) => producto.marcado == 1).toList();

      _compras.removeWhere((p) => p.marcado == 1);
      notifyListeners();

      for (var producto in productosMarcados) {
        await database
            .from('compra')
            .delete()
            .eq('idproducto', producto.idProducto)
            .eq('usuariouuid', userId!);
      }

      // ACTUALIZAMOS LA LISTA DE LA COMPRA
      comprasAgrupadas = {};
      for (var compra in _compras) {
        comprasAgrupadas.putIfAbsent(compra.supermercado, () => []);
        comprasAgrupadas[compra.supermercado]!.add(compra);
      }

    } catch (e) {
      debugPrint('Error al eliminar productos marcados: $e');
      rethrow;
    }
  }

}
