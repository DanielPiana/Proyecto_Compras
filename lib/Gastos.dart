import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class Gastos extends StatefulWidget {
  final Database database;

  const Gastos({super.key, required this.database});

  @override
  State<Gastos> createState() => _GastosState();
}

class _GastosState extends State<Gastos> {
  Map<String, List<Map<String, dynamic>>> _facturasAgrupadas = {};

  @override
  void initState() {
    super.initState();
    _cargarFacturas();
  }

  Future<void> _cargarFacturas() async {
    // Obtener todas las facturas con su fecha
    final facturas = await widget.database.rawQuery('SELECT * FROM facturas ORDER BY fecha DESC');

    // Preparar un mapa para agrupar productos por fecha de factura
    Map<String, List<Map<String, dynamic>>> agrupados = {};

    for (var factura in facturas) {
      final idFactura = factura['id'];
      final fecha = (factura['fecha'] ?? 'Sin fecha').toString();

      // Obtener los productos asociados a esta factura
      final productos = await widget.database.rawQuery('''
        SELECT p.nombre, pf.cantidad, p.precio 
        FROM producto_factura pf
        JOIN productos p ON pf.idProducto = p.id
        WHERE pf.idFactura = ?
      ''', [idFactura]);

      agrupados[fecha] = productos;
    }

    setState(() {
      _facturasAgrupadas = agrupados;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gastos"),
        centerTitle: true,
      ),
      body: _facturasAgrupadas.isEmpty
          ? const Center(
        child: Text(
          "No hay facturas registradas",
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView(
        children: _facturasAgrupadas.entries.map((entry) {
          final fecha = entry.key;
          final productos = entry.value;

          return ExpansionTile(
            title: Text(fecha,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            children: productos.map((producto) {
              return ListTile(
                title: Text(producto['nombre']),
                subtitle: Text('Cantidad: ${producto['cantidad']}'),
                trailing: Text(
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
