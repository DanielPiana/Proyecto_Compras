import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/userProvider.dart';
import 'package:proyectocompras/models/compraModel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import 'compraProvider.dart';


class FacturaProvider extends ChangeNotifier {
  final SupabaseClient database;
  final String userId;

  FacturaProvider(this.database, this.userId);

  /// Genera una factura para un supermercado específico usando los productos marcados en CompraProvider.
  /// Devuelve true si la factura se generó correctamente, false en caso de error o si no hay productos marcados.
  Future<void> generarFactura( BuildContext context,List<CompraModel> productosMarcados) async {
    try {

      // Calculamos el total
      double precioTotal = productosMarcados.fold(
        0.0,
            (sum, producto) => sum + producto.precio * producto.cantidad,
      );

      // Fecha actual
      final fechaActual = DateFormat("dd/MM/yyyy").format(DateTime.now());

      // Obtenemos el usuario desde el provider
      final userId = context.read<UserProvider>().uuid!;

      // Insertamos la factura
      final insertFactura = await database.from('facturas').insert({
        'precio': precioTotal,
        'fecha': fechaActual,
        'usuariouuid': userId,
      }).select().single();

      final idFactura = insertFactura['id'];

      // Insertamos los productos de la factura
      for (var producto in productosMarcados) {
        await database.from('producto_factura').insert({
          'idproducto': producto.idProducto,
          'idfactura': idFactura,
          'cantidad': producto.cantidad,
          'preciounidad': producto.precio,
          'total': producto.precio * producto.cantidad,
          'usuariouuid': userId,
        });
      }

      // Reseteamos los productos marcados y cantidades
      await context.read<CompraProvider>().resetearProductosListaCompra();

      // Mensaje de confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.snackBarAddedReceipt)),
      );
    } catch (e) {
      debugPrint('Error al generar factura: $e');
    }
  }
}