import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class Producto extends StatefulWidget {
  final Database database;

  const Producto({super.key, required this.database});

  @override
  State<Producto> createState() => _ProductoState();
}

class _ProductoState extends State<Producto> {
  List<Map<String, dynamic>> _productos = [];

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  // Método para cargar los productos desde la base de datos
  Future<void> _loadProductos() async {
    final productos = await widget.database.query('productos');
    setState(() {
      _productos = productos;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Productos"),
        centerTitle: true,
      ),
      body: _productos.isEmpty ? const Center(
        child: Text(
          "No hay productos disponibles",
          style: TextStyle(
            color: Color(0xFF212121), // Gris oscuro para el texto
            fontSize: 18,
          ),
        ),
      )
          : ListView.builder(
        itemCount: _productos.length,
        itemBuilder: (context, index) {
          final producto = _productos[index];
          return ListTile(
            leading: const Icon(Icons.fastfood),
            title: Text(producto['nombre'] ?? ''),
            subtitle: Text(producto['descripcion'] ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min, //Hacemos que ocupe el menor tamaño posible
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${double.tryParse(producto['precio'].toString())?.toStringAsFixed(2) ?? '0.00'} €'),
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
        },
      ),
    );
  }
}
