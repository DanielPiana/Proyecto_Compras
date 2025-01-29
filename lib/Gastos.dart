import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class Gastos extends StatefulWidget {
  final Database database;

  const Gastos({super.key, required this.database});

  @override
  State<Gastos> createState() => _GastosState();
}

class _GastosState extends State<Gastos> {
  // LISTA PARA ALMACENAR LAS FACTURAS AGRUPADAS POR FECHA Y ID
  Map<String, List<Map<String, dynamic>>> _facturasAgrupadas = {};

  @override
  void initState() {
    super.initState();
    // CARGAMOS LAS FACTURAS AL ABRIR LA PAGINA
    _cargarFacturas();
  }

  Future<void> _cargarFacturas() async {
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
      _facturasAgrupadas = agrupados;
    });
  }

  /*TODO-----------------DIALOGO DE ELIMINACION DE PRODUCTO EN LISTA-----------------*/
  /// METODO QUE MUESTRA UN DIALOGO DE CONFIRMACION PARA ELIMINAR PRODUCTO DE LA LISTA DE LA COMPRA
  void dialogoEliminacion(BuildContext context, int idFactura) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text( // TITULO DE LA ALERTA
            "Confirmar eliminación",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: const Text(
            "¿Estás seguro de que deseas eliminar esta factura? \n"
                "Los productos asociados no se borrarán",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // CERRAMOS EL DIALOGO
                Navigator.of(context).pop();
              },
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                // BORRAMOS LA FACTURA
                borrarFactura(idFactura);
                _cargarFacturas();
                Navigator.of(context).pop();
              },
              child: const Text(
                "Eliminar",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> borrarFactura (int idFactura) async{
    await widget.database.rawDelete('''
    DELETE FROM facturas WHERE id = ?
    ''', [idFactura]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gastos"), // TÍTULO DEL AppBar
        centerTitle: true,
      ),
      // SI NO HAY FACTURAS MOSTRAMOS UN MENSAJE
      body: _facturasAgrupadas.isEmpty
          ? const Center(
        child: Text(
          "No hay facturas registradas",
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView(
        // MAPEAMOS LAS FACTURAS AGRUPADAS
        children: _facturasAgrupadas.entries.map((entry) {
          // DIVIDIMOS LA CLAVE ÚNICA PARA OBTENER FECHA E ID
          final clave = entry.key.split('-'); // DIVIDIMOS EN [FECHA, ID]
          final fecha = clave[0]; // PRIMERA PARTE: FECHA
          final idFactura = clave[1]; // SEGUNDA PARTE: ID FACTURA
          final productos = entry.value; // LISTA DE PRODUCTOS DE ESA FACTURA

          return ExpansionTile( // 'CARPETAS'
            // MOSTRAMOS EL ID JUNTO CON LA FECHA
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Factura #$idFactura - $fecha',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(onPressed: () {
                  dialogoEliminacion(context,int.parse(idFactura));
                }, icon: Icon(Icons.delete))
              ],
            ),
            // MAPEAMOS LA LISTA DE PRODUCTOS PARA QUE CREE UN ListTile POR CADA PRODUCTO
            children: productos.map((producto) {
              return ListTile(
                title: Text(producto['nombre']),
                subtitle: Text('Cantidad: ${producto['cantidad']}'),
                trailing: Text( // FORMATEAMOS EL PRECIO PARA VISUALIZARLO BIEN
                  '\$${producto['precioUnidad'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
