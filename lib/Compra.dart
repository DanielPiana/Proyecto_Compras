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

  /*TODO-----------------METODO DE CARGAR COMPRA-----------------*/
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

  /*TODO-----------------METODO CALCULAR TOTAL MARCADO-----------------*/
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

  /*TODO-----------------METODO GENERAR FACTURA-----------------*/
  Future<void> _generarFactura() async {
    // Consultar productos marcados
    final productosMarcados = await widget.database.rawQuery(
      'SELECT * FROM compra WHERE marcado = 1',
    );

    if (productosMarcados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos marcados para generar una factura.')),
      );
      return;
    }

    // Calcular el precio total de los productos marcados
    double precioTotal = productosMarcados.fold(0.0, (sum, producto) {
      return sum + (producto['precio'] as num).toDouble();
    });

    // Obtener solo la fecha actual (YYYY-MM-DD)
    final fechaActual = DateTime.now().toIso8601String().split('T')[0];

    // Insertar nueva factura
    final idFactura = await widget.database.insert('facturas', {
      'precio': precioTotal,
      'fecha': fechaActual, // Usamos la fecha simplificada
      'supermercado': 'Supermercado Desconocido', // Cambiar según corresponda
    });

    // Asociar productos marcados a la factura
    for (var producto in productosMarcados) {
      await widget.database.insert('producto_factura', {
        'idProducto': producto['idProducto'],
        'idFactura': idFactura,
        'cantidad': 1, // Ajustar según la lógica de cantidades
      });
    }

    // Mostrar mensaje de éxito
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Factura generada correctamente.')),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lista de la Compra"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt),
            onPressed: _generarFactura,
            tooltip: 'Generar Factura',
          ),
        ],
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
