import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/compraModel.dart';
import '../models/productoModel.dart';
import '../utils/capitalize.dart';

class DuplicateProductException implements Exception {}

class CompraProvider extends ChangeNotifier {
  final SupabaseClient database;
  String? userId;

  // LISTA DE COMPRAS CARGADAS DESDE LA BASE DE DATOS
  List<CompraModel> _compras = [];

  List<CompraModel> get compras => _compras;

  // LISTA AGRUPADA POR SUPERMERCADO
  Map<String, List<CompraModel>> comprasAgrupadas = {};
  double precioTotalCompra = 0.0;

  CompraProvider(this.database, this.userId);

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

  /// CARGA LOS PRODUCTOS DE LA COMPRA Y LOS AGRUPA POR SUPERMERCADO
  Future<void> cargarCompra() async {
    final response = await database
        .from('compra')
        .select('*, productos(supermercado)')
        .eq('usuariouuid', userId!);

    final List productos = response as List;

    _compras = [];
    comprasAgrupadas = {};
    precioTotalCompra = 0.0;

    // CONSTRUIMOS LA LISTA LOCAL
    for (var p in productos) {
      final compra = CompraModel.fromMap(p);
      _compras.add(compra);
    }

    ordenarCompras(_compras);

    // AGRUPAMOS POR SUPERMERCADO, FORZANDO NUEVA REFERENCIA DEL MAP PARA QUE CARGUE BIEN
    for (var compra in _compras) {
      final supermercado =
          compra.supermercado;

      comprasAgrupadas = Map.from(comprasAgrupadas)
        ..putIfAbsent(supermercado, () => [])
        ..[supermercado]!.add(compra);

    if (compra.marcado == 1) {
    precioTotalCompra += compra.precio * compra.cantidad;
    }
  }

    notifyListeners();
  }

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

  Future<void> deleteProducto(int idProducto) async {

    eliminarProductoLocal(idProducto);

    try {
      await database
          .from('compra')
          .delete()
          .eq('idproducto', idProducto)
          .eq('usuariouuid', userId!);
    } catch (e) {
      debugPrint("Error al eliminar producto: $e");
      await cargarCompra();
    }
  }

  void eliminarProductoLocal(int idProducto) {
    // BUSCAMOS EL INDICE Y GUARDAMOS EL PRODUCTO
    final index = _compras.indexWhere((p) => p.idProducto == idProducto);
    if (index == -1) return; // No existe
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

  Future<void> agregarACompra(
      int idProducto,
      double precio,
      String nombre,
      String supermercado,
      ) async {
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
}
