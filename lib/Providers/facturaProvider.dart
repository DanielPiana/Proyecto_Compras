import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:proyectocompras/models/compraModel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facturaModel.dart';
import '../models/productoFacturaModel.dart';


class FacturaProvider extends ChangeNotifier {
  final SupabaseClient database;
  String? userId;

  List<FacturaModel> _facturas = [];
  List<FacturaModel> get facturas => _facturas;

  FacturaProvider(this.database, this.userId);

  Future<void> setUserAndReload(String? uuid) async {
    userId = uuid;
    if (uuid == null) {
      _facturas = [];
      notifyListeners();
      return;
    }
    await cargarFacturas();
  }


  /// Genera una factura para un supermercado específico usando los productos marcados en CompraProvider.
  /// Devuelve true si la factura se generó correctamente, false en caso de error o si no hay productos marcados.
  Future<void> generarFactura(List<CompraModel> productosMarcados, String uuidUsuario,) async {
    try {
      final double precioTotal = productosMarcados.fold(
        0.0,
            (sum, producto) => sum + producto.precio * producto.cantidad,
      );

      final fechaActual = DateFormat("dd/MM/yyyy").format(DateTime.now());

      final insertFactura = await database.from('facturas').insert({
        'precio': precioTotal,
        'fecha': fechaActual,
        'usuariouuid': uuidUsuario,
      }).select().single();

      final idFactura = insertFactura['id'];

      for (var producto in productosMarcados) {
        await database.from('producto_factura').insert({
          'idproducto': producto.idProducto,
          'idfactura': idFactura,
          'cantidad': producto.cantidad,
          'preciounidad': producto.precio,
          'total': producto.precio * producto.cantidad,
          'usuariouuid': uuidUsuario,
        });
      }

      final nuevaFactura = FacturaModel(
        id: idFactura,
        precio: precioTotal,
        fecha: fechaActual,
        usuariouuid: uuidUsuario,
        productos: productosMarcados.map((p) {
          return ProductoFacturaModel(
            nombre: p.nombre,
            cantidad: p.cantidad,
            precioUnidad: p.precio,
          );
        }).toList(),
      );

      _facturas.insert(0, nuevaFactura);
      notifyListeners();
    } catch (e) {
      debugPrint('Error al generar factura: $e');
      rethrow;
    }
  }

  Future<void> cargarFacturas() async {
    try {
      final facturasData = await database
          .from('facturas')
          .select()
          .eq('usuariouuid', userId!)
          .order('id', ascending: false);

      final List<FacturaModel> cargadas = [];

      for (var factura in facturasData) {
        final idFactura = factura['id'];
        final productosData = await database
            .from('producto_factura')
            .select('cantidad, preciounidad, productos(nombre)')
            .eq('idfactura', idFactura);

        final productosList = (productosData as List).map((item) {
          return ProductoFacturaModel.fromMap(item);
        }).toList();

        cargadas.add(
          FacturaModel(
            id: factura['id'],
            precio: (factura['precio'] as num).toDouble(),
            fecha: factura['fecha'].toString(),
            usuariouuid: factura['usuariouuid'],
            productos: productosList,
          ),
        );
      }

      _facturas = cargadas;
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar facturas: $e');
    }
  }

  Future<void> borrarFactura(int idFactura, String uuidUsuario) async {
    final backup = List<FacturaModel>.from(facturas);

    facturas.removeWhere((f) => f.id == idFactura);
    notifyListeners();

    try {
      await database.from('producto_factura').delete().eq('idfactura', idFactura);

      await database
          .from('facturas')
          .delete()
          .eq('id', idFactura)
          .eq('usuariouuid', uuidUsuario);
    } catch (e) {
      debugPrint('Error al borrar factura: $e');
      _facturas = backup;
      notifyListeners();
      rethrow;
    }
  }

}