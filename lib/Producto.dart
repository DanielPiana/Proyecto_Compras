import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class Producto extends StatefulWidget {
  final Database database;

  const Producto({super.key, required this.database});

  @override
  State<Producto> createState() => _ProductoState();
}

class _ProductoState extends State<Producto> {
  Map<String, List<Map<String, dynamic>>> _productosPorSupermercado = {};

  @override
  void initState() {
    super.initState();
    cargarProductos();
  }

  // Método para cargar y agrupar los productos desde la base de datos
  Future<void> cargarProductos() async {
    final productos = await widget.database.query('productos');
    final Map<String, List<Map<String, dynamic>>> agrupados = {};

    for (var producto in productos) {
      final supermercado = (producto['supermercado'] ?? 'Sin supermercado').toString();
      if (!agrupados.containsKey(supermercado)) {
        agrupados[supermercado] = [];
      }
      agrupados[supermercado]?.add(producto);
    }

    setState(() {
      _productosPorSupermercado = agrupados;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Productos"),
        centerTitle: true,
      ),
      body: _productosPorSupermercado.isEmpty ? const Center(
        child: Text(
          "No hay productos disponibles",
          style: TextStyle(
            color: Color(0xFF212121), // Gris oscuro para el texto
            fontSize: 18,
          ),
        ),
      )
          : ListView(
        children: _productosPorSupermercado.entries.map((entry) {
          final supermercado = entry.key;
          final productos = entry.value;

          return ExpansionTile(
            title: Text(
              supermercado,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            children: productos.map((producto) {
              return ListTile(
                leading: const Icon(Icons.fastfood),
                title: Text(producto['nombre'] ?? ''),
                subtitle: Text(producto['descripcion'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min, // Ocupa el menor tamaño posible
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${double.tryParse(producto['precio'].toString())?.toStringAsFixed(2) ?? '0.00'} €',
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 25,
                      height: 25,
                      child: IconButton(
                        icon: const Icon(Icons.add),
                        iconSize: 20.0,
                        onPressed: () {
                          debugPrint('Añadir producto');
                        },
                        padding: EdgeInsets.zero, // Elimina el relleno interno del botón
                      ),
                    ),
                    SizedBox(
                      width: 25,
                      height: 25,
                      child: IconButton(
                        icon: const Icon(Icons.edit),
                        iconSize: 20.0,
                        onPressed: () {
                          debugPrint('Editar producto');
                        },
                        padding: EdgeInsets.zero, // Elimina el relleno interno del botón
                      ),
                    ),
                    SizedBox(
                      width: 25,
                      height: 25,
                      child: IconButton(
                        icon: const Icon(Icons.delete),
                        iconSize: 20.0,
                        onPressed: () {
                          debugPrint('Eliminar producto');
                        },
                        padding: EdgeInsets.zero, // Elimina el relleno interno del botón
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
