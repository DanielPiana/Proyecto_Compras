import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Gastos extends StatefulWidget {
  final Database database;

  const Gastos({super.key, required this.database});

  @override
  State<Gastos> createState() => GastosState();
}

class GastosState extends State<Gastos> {
  // LISTA PARA ALMACENAR LAS FACTURAS AGRUPADAS POR FECHA Y ID
  Map<String, List<Map<String, dynamic>>> facturasAgrupadas = {};

  @override
  void initState() {
    super.initState();
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
    // CONSULTA PARA OBTENER LAS FACTURAS ORDENADAS POR FECHA DESCENDENTE
    final facturas = await widget.database.rawQuery(
      'SELECT * FROM facturas ORDER BY facturas.id DESC',
    );

    // MAPA PARA AGRUPAR LAS FACTURAS USANDO UNA CLAVE ÚNICA (FECHA + ID)
    Map<String, List<Map<String, dynamic>>> agrupados = {};

    // ITERAMOS SOBRE CADA FACTURA OBTENIDA DE LA CONSULTA
    for (var factura in facturas) {
      // GUARDAMOS EL ID DE LA FACTURA
      final idFactura = factura['id'];

      // GUARDAMOS LA FECHA DE LA FACTURA, SI NO TIENE FECHA PONEMOS "Sin fecha"
      final fecha = (factura['fecha'] ?? 'Sin fecha').toString();

      // CONSULTA PARA OBTENER TODOS LOS PRODUCTOS DE ESA FACTURA EN CONCRETO
      final productos = await widget.database.rawQuery('''
        SELECT p.nombre, pf.cantidad, pf.precioUnidad 
        FROM producto_factura pf
        JOIN productos p ON pf.idProducto = p.id
        WHERE pf.idFactura = ?
      ''', [idFactura]);

      // USAMOS UNA CLAVE ÚNICA (FECHA + ID) PARA EVITAR AGRUPAR FACTURAS INCORRECTAMENTE
      agrupados['$fecha-$idFactura'] = productos;
    }

    setState(() {
      // ACTUALIZAMOS EL ESTADO CON LAS FACTURAS AGRUPADAS
      facturasAgrupadas = agrupados;
    });
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
                borrarFactura(idFactura);
                cargarFacturas();
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
  Future<void> borrarFactura (int idFactura) async{
    await widget.database.rawDelete('''
    DELETE FROM facturas WHERE id = ?
    ''', [idFactura]);
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
        child: Text(
          "No hay facturas registradas",
          style: TextStyle(fontSize: 18),
        ),
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
            precioTotal += producto['precioUnidad'] * producto['cantidad'];
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
                    '\$${producto['precioUnidad'].toStringAsFixed(2)}',
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