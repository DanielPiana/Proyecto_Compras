import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Providers/userProvider.dart';
import '../l10n/app_localizations.dart';

class Gastos extends StatefulWidget {

  const Gastos({super.key});

  @override
  State<Gastos> createState() => GastosState();
}

class GastosState extends State<Gastos> {

  SupabaseClient database = Supabase.instance.client;

  // LISTA PARA ALMACENAR LAS FACTURAS AGRUPADAS POR FECHA Y ID
  Map<String, List<Map<String, dynamic>>> facturasAgrupadas = {};

  @override
  void initState() {
    super.initState();
    final userId = context.read<UserProvider>().uuid;
    // CARGAMOS LAS FACTURAS AL ABRIR LA PAGINA
    cargarFacturas();

  }
  /// Carga las facturas desde la base de datos y agrupa los productos por id.
  ///
  /// Realiza una consulta a la base de datos para obtener todas las facturas ordenadas
  /// por id en orden descendente. Luego, para cada factura, se realiza una segunda
  /// consulta para obtener todos los productos asociados a dicha factura. Los productos
  /// se agrupan utilizando una clave única que combina la fecha y el ID de la factura.
  /// Si una factura no tiene fecha, se asigna el valor "Sin fecha".
  ///
  /// Los productos de cada factura se almacenan en un mapa, donde la clave es la combinación
  /// de la fecha y el ID de la factura, y el valor es una lista de los productos correspondientes
  /// a esa factura.
  ///
  /// Finalmente, se actualiza el estado de la interfaz con las facturas agrupadas y sus productos.
  ///
  /// Este proceso de carga y agrupación es asincrónico y se realiza de manera eficiente para
  /// evitar bloquear la interfaz de usuario mientras se obtiene la información de la base de datos.
  Future<void> cargarFacturas() async {
    try {
      final facturas = await database
          .from('facturas')
          .select()
          .eq('usuariouuid', context.read<UserProvider>().uuid!)
          .order('id', ascending: false);

      Map<String, List<Map<String, dynamic>>> agrupados = {};

      for (var factura in facturas) {
        final idFactura = factura['id'];
        final fecha = (factura['fecha'] ?? 'Sin fecha').toString();

        final productos = await database
            .from('producto_factura')
            .select('cantidad, preciounidad, productos(nombre)')
            .eq('idfactura', idFactura);

        final productosList = (productos as List).map<Map<String, dynamic>>((item) {
          return {
            'nombre': item['productos']['nombre'],
            'cantidad': item['cantidad'],
            'preciounidad': item['preciounidad'],
          };
        }).toList();

        agrupados['$fecha-$idFactura'] = productosList;
      }

      setState(() {
        facturasAgrupadas = agrupados;
      });
    } catch (e) {
      debugPrint('Error al cargar facturas: $e');
    }
  }



  /*TODO-----------------DIALOGO DE ELIMINACION DE PRODUCTO EN LISTA-----------------*/
  /// Muestra un cuadro de diálogo de confirmación para la eliminación de una factura.
  ///
  /// Este método muestra un 'AlertDialog' en el que se le pregunta al usuario si está
  /// seguro de eliminar una factura específica. El cuadro de diálogo contiene dos botones:
  /// - "Cancelar": Cierra el cuadro de diálogo sin realizar ninguna acción.
  /// - "Eliminar": Elimina la factura especificada por el 'idFactura' y recarga las facturas.
  ///
  /// Además, se informa al usuario de que los productos asociados a la factura no serán eliminados.
  ///
  /// El cuadro de diálogo se muestra de forma asincrónica y se cierra automáticamente al
  /// confirmar la eliminación o al cancelar la acción.
  void dialogoEliminacion(BuildContext context, int idFactura) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text( // TITULO DE LA ALERTA
            AppLocalizations.of(context)!.titleConfirmDialog,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content:  Text(
            AppLocalizations.of(context)!.deleteConfirmationR,
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // CERRAMOS EL DIALOGO
                Navigator.of(context).pop();
              },
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                // BORRAMOS LA FACTURA
                await borrarFactura(idFactura);
                await cargarFacturas();
                Navigator.of(context).pop();
              },
              child: Text(
                AppLocalizations.of(context)!.delete,
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Elimina un producto de la base de datos según su ID.
  ///
  /// Si el producto existe en la tabla 'productos' con el ID proporcionado se elimina
  ///
  /// Parámetros:
  /// - [id]: ID único de la factura a eliminar.
  Future<void> borrarFactura(int idFactura) async {
    try {
      // Primero borramos los productos asociados a la factura
      await database
          .from('producto_factura')
          .delete()
          .eq('idfactura', idFactura);

      // Luego borramos la factura en sí
      await database
          .from('facturas')
          .delete()
          .eq('id', idFactura)
          .eq('usuariouuid', context.read<UserProvider>().uuid!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Factura eliminada correctamente')),
      );
    } catch (e) {
      debugPrint('Error al borrar factura: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((AppLocalizations.of(context)!.receipt)), // TÍTULO DEL AppBar
        centerTitle: true,
      ),
      // SI NO HAY FACTURAS MOSTRAMOS UN MENSAJE
      body: facturasAgrupadas.isEmpty
          ? const Center(
        child: CircularProgressIndicator()
      )
          : ListView(
        // MAPEAMOS LAS FACTURAS AGRUPADAS
        children: facturasAgrupadas.entries.map((entry) {
          // DIVIDIMOS LA CLAVE ÚNICA PARA OBTENER FECHA E ID
          final clave = entry.key.split('-'); // DIVIDIMOS EN [FECHA, ID]
          final fecha = clave[0]; // PRIMERA PARTE: FECHA
          final idFactura = clave[1]; // SEGUNDA PARTE: ID FACTURA
          final productos = entry.value; // LISTA DE PRODUCTOS DE ESA FACTURA

          // CALCULAMOS EL PRECIO TOTAL DE LA FACTURA
          double precioTotal = 0;
          for (var producto in productos) {
            precioTotal += producto['preciounidad'] * producto['cantidad'];
          }

          return ExpansionTile( // 'CARPETAS'
            // MOSTRAMOS EL ID JUNTO CON LA FECHA
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fecha,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    dialogoEliminacion(context, int.parse(idFactura));
                  },
                  icon: const Icon(Icons.delete),
                ),
              ],
            ),
            // MAPEAMOS LA LISTA DE PRODUCTOS PARA QUE CREE UN ListTile POR CADA PRODUCTO
            children: [
              ...productos.map((producto) {
                return ListTile(
                  title: Text(producto['nombre']),
                  subtitle: Text('${AppLocalizations.of(context)!.quantity}: ${producto['cantidad']}'),
                  trailing: Text( // FORMATEAMOS EL PRECIO PARA VISUALIZARLO BIEN
                    '\$${producto['preciounidad'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                );
              }).toList(),
              ListTile(
                title: Text(
                  AppLocalizations.of(context)!.totalPrice,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  '\$${precioTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 20
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}