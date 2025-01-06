import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class Compra extends StatefulWidget {
  final Database database;

  const Compra({Key? key, required this.database}) : super(key: key);

  @override
  State<Compra> createState() => _CompraState();
}

class _CompraState extends State<Compra> {
  Map<String, List<Map<String, dynamic>>> _productosPorSupermercado = {};

  @override
  void initState() {
    super.initState();
    _cargarCompra();
  }

  Future<void> _cargarCompra() async {
    try {
      final productos = await widget.database.rawQuery('''
      SELECT DISTINCT c.idProducto, c.precio, c.marcado, p.nombre, p.supermercado
      FROM compra c
      JOIN productos p ON c.idProducto = p.id
      ORDER BY p.supermercado;
    ''');

      debugPrint('Productos cargados: $productos');

      // Mapa para agrupar por supermercado
      final agrupados = <String, List<Map<String, dynamic>>>{};
      final productosUnicos = <int>{}; // Set para rastrear productos únicos por id

      for (var producto in productos) {
        final idProducto = producto['idProducto'] as int;

        // Solo agregar si no está ya en el conjunto
        if (!productosUnicos.contains(idProducto)) {
          productosUnicos.add(idProducto);

          final supermercado = producto['supermercado']?.toString() ?? 'Sin supermercado';
          if (!agrupados.containsKey(supermercado)) {
            agrupados[supermercado] = [];
          }
          agrupados[supermercado]!.add(producto);
        }
      }

      setState(() {
        _productosPorSupermercado = agrupados;
      });
    } catch (e) {
      debugPrint('Error al cargar productos en compra: $e');
    }
  }


  Future<void> _marcarProducto(int idProducto, bool marcado) async {
    try {
      await widget.database.update(
        'compra',
        {'marcado': marcado ? 1 : 0},
        where: 'idProducto = ?',
        whereArgs: [idProducto],
      );
      _cargarCompra(); // Recargar la lista de compras
    } catch (e) {
      debugPrint('Error al marcar producto: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lista de la Compra"),
        centerTitle: true,
      ),
      body: _productosPorSupermercado.isEmpty
          ? const Center(child: Text('No hay productos en la lista de compra.'))
          : ListView(
        children: _productosPorSupermercado.entries.map((entry) {
          final supermercado = entry.key;
          final productos = entry.value;

          return ExpansionTile(
            title: Text(supermercado),
            children: productos.map((producto) {
              return ListTile(
                leading: IconButton(
                  icon: Icon(
                    producto['marcado'] == 1 ? Icons.check_box : Icons.check_box_outline_blank,
                    color: producto['marcado'] == 1 ? Colors.green : Colors.grey,
                  ),
                  onPressed: () async {
                    // Cambiar el estado de marcado/desmarcado
                    final nuevoEstado = producto['marcado'] == 1 ? 0 : 1;
                    await widget.database.rawUpdate(
                      'UPDATE compra SET marcado = ? WHERE idProducto = ?',
                      [nuevoEstado, producto['idProducto']],
                    );
                    // Recargar la lista
                    _cargarCompra();
                  },
                ),
                title: Text(
                  producto['nombre'].toString(),
                  style: TextStyle(
                    decoration: producto['marcado'] == 1
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: producto['marcado'] == 1 ? Colors.grey : Colors.black,
                  ),
                ),
                trailing: Text(
                  '\$${producto['precio'].toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
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
