import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/compraModel.dart';

class CompraProvider extends ChangeNotifier {
  final SupabaseClient database;
  final String userId;

  // Lista de compras cargadas desde la base de datos
  List<CompraModel> _compras = [];
  List<CompraModel> get compras => _compras;

  // Lista agrupada por supermercado
  Map<String, List<CompraModel>> comprasAgrupadas = {};
  double precioTotalCompra = 0.0;

  CompraProvider(this.database, this.userId);

  void alternarMarcado(CompraModel producto) {
    // Cambiamos el estado
    producto.marcado = producto.marcado == 1 ? 0 : 1;

    // Actualizamos precio total
    if (producto.marcado == 1) {
      precioTotalCompra += producto.precio * producto.cantidad;
    } else {
      precioTotalCompra -= producto.precio * producto.cantidad;
    }
    notifyListeners();
  }


  /// Carga los productos de la compra y los agrupa por supermercado.
  Future<void> cargarCompra() async {
    final response = await database
        .from('compra')
        .select('*, productos(supermercado)')
        .eq('usuariouuid', userId);

    final List productos = response as List;

    comprasAgrupadas = {};

    precioTotalCompra = 0.0;

    for (var p in productos) {
      final compra = CompraModel.fromMap(p);

      final supermercado = compra.supermercado;

      if (!comprasAgrupadas.containsKey(supermercado)) {
        comprasAgrupadas[supermercado] = [];
      }

      comprasAgrupadas[supermercado]!.add(compra);

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
        // No se encontró el producto, no hacemos nada
      }
    });
    notifyListeners();
  }


  // Resetear toda la lista
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
    try {
      await database
          .from('compra')
          .delete()
          .eq('idproducto', idProducto)
          .eq('usuariouuid', userId);

      debugPrint('Producto eliminado');

      await cargarCompra();
    } catch (e) {
      debugPrint('Error al borrar producto: $e');
    }
  }

  void actualizarPrecio(int idProducto, double precio, int cantidad) {
    // Restamos el precio del producto eliminado
    precioTotalCompra -= precio * cantidad;

    String? supermercadoAEliminar;

    comprasAgrupadas.forEach((supermercado, lista) {
      final pIndex = lista.indexWhere((p) => p.idProducto == idProducto);
      if (pIndex != -1) {
        lista.removeAt(pIndex); // Eliminamos el producto
        if (lista.isEmpty) {
          supermercadoAEliminar = supermercado; // Marcamos el supermercado vacío
        }
      }
    });
    // Si algún supermercado quedó vacío, lo eliminamos del mapa
    if (supermercadoAEliminar != null) {
      comprasAgrupadas.remove(supermercadoAEliminar);
    }

    notifyListeners();
  }

  Future<void> agregarACompra({
    required int idProducto,
    required double precio,
    required String nombre,
  }) async {
    try {

      final productosExistentes = await database
          .from('compra')
          .select()
          .eq('idproducto', idProducto)
          .eq('usuariouuid', userId);

      if (productosExistentes.isNotEmpty) {
        throw Exception("Producto ya registrado");
      } else {
        await database.from('compra').insert({
          'idproducto': idProducto,
          'nombre': nombre,
          'precio': precio,
          'marcado': 0,
          'usuariouuid': userId,
        });
        cargarCompra();
      }
    } catch (e) {
      debugPrint("Error agregando producto a la compra: $e");
      rethrow;
    }
  }
}