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

  /// METODO PARA ESTABLECER UN USUARIO Y RECARGAR SUS PRODUCTOS
  Future<void> setUserAndReload(String? uuid) async {
    userId = uuid;
    if (uuid == null) {
      _facturas = [];
      notifyListeners();
      return;
    }
    await cargarFacturas();
  }

  /// Genera una factura a partir de los productos marcados de la lista de la compra
  ///
  /// Flujo principal:
  /// - Recalcula el precio total de los productos marcados
  /// - Intenta insertar la fecha en la base de datos
  /// - Recuperamos el id de la factura que acabamos de insertar
  /// e insertamos en producto_factura todos los productos relacionados
  /// con el id de la factura asociado
  /// Creamos el modelo de [FacturaModel]
  /// Lo insertamos en la lista local y notificamos a los listeners
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

  /// Carga las facturas del usuario desde la base de datos
  ///
  /// Flujo principal:
  /// - Consulta la tabla 'facturas' en la base de datos, filtrando por [userId]
  /// - Convierte los resultados en una lista de [FacturaModel]
  /// - Notifica a los listeners para actualizar la UI
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

  /// Elimina una factura de la base de datos y sus productos relacionados
  /// de la tabla 'producto_factura'
  /// Flujo principal:
  /// Realizamos una copia de seguridad de la lista local de facturas
  /// Eliminamos la factura de la lista local y notificamos a los listeners
  /// Eliminamos los productos asociados a esa factura de la tabla 'producto_factura'
  /// Eliminamos la factura de la base de datos, si da un error, volvemos a
  /// insertar la factura en la lista local y notificamos a los listeners
  Future<void> borrarFactura(int idFactura, String uuidUsuario) async {

    final backup = List<FacturaModel>.from(facturas);

    facturas.removeWhere((f) => f.id == idFactura);
    notifyListeners();

    try {
      // TODO comprobar si borramos en producto_factura funciona y luego da erroe en facturas, se restaura en producto_factura
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