import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class Gastos extends StatefulWidget {
  final Database database;

  const Gastos({super.key, required this.database});

  @override
  State<Gastos> createState() => _GastosState();
}

class _GastosState extends State<Gastos> {
  // LISTA PARA ALMACENAR LAS FACTURAS AGRUPADOS POR FECHA
  Map<String, List<Map<String, dynamic>>> _facturasAgrupadas = {};

  @override
  void initState() {
    super.initState();
    // CARGAMOS LAS FACTURAS AL ABRIR LA PAGINA
    _cargarFacturas();
  }

  Future<void> _cargarFacturas() async {
    // CONSULTA PATA OBTENER LAS FACURAS ORDENADAS POR FECHA DESCENDIENTE
    final facturas = await widget.database.rawQuery('SELECT * FROM facturas ORDER BY fecha DESC');

    // MAPA PARA AGRUPAR LOS PRODUCTOS POR FECHA
    Map<String, List<Map<String, dynamic>>> agrupados = {};

    // ITERAMOS SOBRE CADA PRODUCTO OBTENIDO DE LA CONSULTA
    for (var factura in facturas) {
      // GUARDAMOS EL ID DE LA FACTURA
      final idFactura = factura['id'];

      // GUARDAMOS LA FECHA DE LA FACTURA, SI NO TIENE FECHA PONEMOS Sin fecha
      final fecha = (factura['fecha'] ?? 'Sin fecha').toString();

      // CONSULTA PARA OBTENER TODOS LOS PRODUCTOS DE ESA FECHA EN CONCRETO
      final productos = await widget.database.rawQuery('''
        SELECT p.nombre, pf.cantidad, p.precio 
        FROM producto_factura pf
        JOIN productos p ON pf.idProducto = p.id
        WHERE pf.idFactura = ?
      ''', [idFactura]);

      // ACTUALIZAMOS
      agrupados[fecha] = productos;
    }

    setState(() {
      // ACTUALIZAMOS
      _facturasAgrupadas = agrupados;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gastos"), // TITULO DEL AppBar
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
          final fecha = entry.key; // COGEMOS LA FECHA
          final productos = entry.value; // COGEMOS LA LISTA DE PRODUCTOS DE ESA FECHA

          return ExpansionTile( // 'CARPETAS'
            title: Text(fecha,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            // MAPEAMOS LA LISTA PRODUCTOS PARA QUE CREE UN ListTile POR CADA PRODUCTO
            children: productos.map((producto) {
              return ListTile(
                title: Text(producto['nombre']),
                subtitle: Text('Cantidad: ${producto['cantidad']}'),
                trailing: Text( // FORMATEAMOS EL PRECIO PARA VISUALIZARLO BIEN
                  '\$${producto['precio'].toStringAsFixed(2)}',
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
