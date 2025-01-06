import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class Compra extends StatefulWidget {
  final Database database;

  const Compra({super.key, required this.database});

  @override
  State<Compra> createState() => _CompraState();
}

class _CompraState extends State<Compra> {
  List<Map<String, dynamic>> _productosCompra = [];
  double _totalMarcados = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarCompra();
  }

  Future<void> _cargarCompra() async {
    final productos = await widget.database.rawQuery('''
    SELECT compra.*, productos.supermercado 
    FROM compra 
    INNER JOIN productos 
    ON compra.idProducto = productos.id
  ''');

    // Agrupamos por supermercado
    final Map<String, List<Map<String, dynamic>>> agrupados = {};
    for (var producto in productos) {
      final supermercado = (producto['supermercado'] ?? 'Sin supermercado').toString();
      if (!agrupados.containsKey(supermercado)) {
        agrupados[supermercado] = [];
      }
      agrupados[supermercado]?.add(producto);
    }

    setState(() {
      _productosCompra = agrupados.entries.map((entry) {
        return {
          'supermercado': entry.key,
          'productos': entry.value,
        };
      }).toList();
    });

    _calcularTotalMarcados(); // Actualizar el total marcado
  }



  Future<void> _calcularTotalMarcados() async {
    // Consultar el total de los productos marcados
    final resultado = await widget.database.rawQuery(
      'SELECT SUM(precio) as total FROM compra WHERE marcado = 1',
    );
    setState(() {
      // Manejar el caso en que el resultado sea null
      _totalMarcados = (resultado.isNotEmpty && resultado[0]['total'] != null)
          ? (resultado[0]['total'] as num).toDouble()
          : 0.0;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lista de la Compra"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _productosCompra.length,
              itemBuilder: (context, index) {
                final grupo = _productosCompra[index];
                final supermercado = grupo['supermercado'];
                final productos = grupo['productos'] as List<Map<String, dynamic>>;

                return ExpansionTile(
                  title: Text(supermercado),
                  children: productos.map((producto) {
                    return ListTile(
                      leading: IconButton(
                        icon: Icon(
                          producto['marcado'] == 1
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: producto['marcado'] == 1 ? Colors.green : Colors.grey,
                        ),
                        onPressed: () async {
                          final nuevoEstado = producto['marcado'] == 1 ? 0 : 1;
                          await widget.database.rawUpdate(
                            'UPDATE compra SET marcado = ? WHERE idProducto = ?',
                            [nuevoEstado, producto['idProducto']],
                          );
                          _cargarCompra();
                        },
                      ),
                      title: Text(producto['nombre']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${producto['precio'].toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await widget.database.rawDelete(
                                'DELETE FROM compra WHERE idProducto = ?',
                                [producto['idProducto']],
                              );
                              _cargarCompra();
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total marcado:",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${_totalMarcados.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
