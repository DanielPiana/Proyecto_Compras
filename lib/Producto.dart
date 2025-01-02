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

  /*TODO-----------------INITIALIZE-----------------*/
  @override
  void initState() {
    super.initState();
    cargarProductos();
  }

  /*TODO-----------------METODO DE CARGAR-----------------*/
  Future<void> cargarProductos() async {
    final productos = await widget.database.query('productos');
    final Map<String, List<Map<String, dynamic>>> agrupados = {};

    for (var producto in productos) {
      final supermercado =
          (producto['supermercado'] ?? 'Sin supermercado').toString();
      if (!agrupados.containsKey(supermercado)) {
        agrupados[supermercado] = [];
      }
      agrupados[supermercado]?.add(producto);
    }

    setState(() {
      _productosPorSupermercado = agrupados;
    });
  }

  /*TODO-----------------METODO DE ELIMINAR-----------------*/
  Future<void> deleteProducto(int id) async {
    try {
      await widget.database.delete(
        // Cambia database por widget.database
        'productos', // Nombre de la tabla
        where: 'id = ?', // Condición para identificar el registro
        whereArgs: [id], // Argumentos para la condición
      );
      debugPrint('Producto con id $id eliminado exitosamente.');

      // Recarga los productos para reflejar el cambio
      await cargarProductos();
    } catch (e) {
      debugPrint('Error al eliminar producto: $e');
    }
  }

  /*TODO-----------------METODO DE EDITAR-----------------*/
  Future<void> actualizarProducto(Map<String, dynamic> producto) async {
    try {
      await widget.database.update(
        'productos',
        {
          'nombre': producto['nombre'],
          'descripcion': producto['descripcion'],
          'precio': producto['precio'],
          'supermercado': producto['supermercado'],
        },
        where: 'id = ?',
        whereArgs: [producto['id']],
      );
      debugPrint('Producto actualizado exitosamente.');
    } catch (e) {
      debugPrint('Error al actualizar el producto: $e');
    }
  }

  /*TODO-----------------METODO DE LISTADO DE SUPERMERCADOS-----------------*/
  Future<List<String>> obtenerSupermercados() async {
    final productos = await widget.database.query('productos');
    final supermercados = productos.map((producto) => producto['supermercado'] as String).toSet().toList();
    return supermercados;
  }

  /*TODO-----------------DIALOGO DE ELIMINACION-----------------*/
  void dialogoEliminacion(BuildContext context, int idProducto) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Confirmar eliminación",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: const Text(
            "¿Estás seguro de que deseas eliminar este producto?",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Cierra el diálogo
                Navigator.of(context).pop();
              },
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                // Borramos el producto
                await deleteProducto(idProducto);
                //Cerramos el diálogo y actualizamos los productos
                Navigator.of(context).pop();
                cargarProductos();
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

  /*TODO-----------------DIALOGO DE EDICION-----------------*/
  void dialogoEdicion(BuildContext context, Map<String, dynamic> producto) async {
    // Creamos los controladores para los campos de texto
    final TextEditingController nombreController = TextEditingController(text: producto['nombre']);
    final TextEditingController descripcionController = TextEditingController(text: producto['descripcion']);
    final TextEditingController precioController = TextEditingController(text: producto['precio'].toString());

    // Obtenemos la lista de supermercados únicos
    final List<String> supermercados = await obtenerSupermercados();

    // Inicializamos el supermercado seleccionado
    String supermercadoSeleccionado = producto['supermercado'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Editar producto"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              TextField(
                controller: precioController,
                decoration: const InputDecoration(labelText: 'Precio'),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<String>(
                value: supermercadoSeleccionado,
                decoration: const InputDecoration(labelText: 'Supermercado'),
                items: supermercados.map((supermercado) {
                  return DropdownMenuItem<String>(
                    value: supermercado,
                    child: Text(supermercado),
                  );
                }).toList(),
                onChanged: (nuevoSupermercado) {
                  if (nuevoSupermercado != null) {
                    supermercadoSeleccionado = nuevoSupermercado;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Cierra el diálogo
                Navigator.of(context).pop();
              },
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () async {
                // Cogemos los datos de los controladores
                final String nuevoNombre = nombreController.text;
                final String nuevaDescripcion = descripcionController.text;
                final double nuevoPrecio = double.tryParse(precioController.text) ?? 0.0;

                // Creamos un nuevo producto con los datos actualizados
                final nuevoProducto = {
                  'id': producto['id'],
                  'nombre': nuevoNombre,
                  'descripcion': nuevaDescripcion,
                  'precio': nuevoPrecio,
                  'supermercado': supermercadoSeleccionado,
                };

                // Actualizamos el producto
                await actualizarProducto(nuevoProducto);

                // Cierra el diálogo y recarga los productos
                Navigator.of(context).pop();
                cargarProductos();
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Productos"),
        centerTitle: true,
      ),
      body: _productosPorSupermercado.isEmpty
          ? const Center(
              child: Text(
                "No hay productos disponibles",
                style: TextStyle(
                  color: Color(0xFF212121),
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
                        // Ocupa el menor tamaño posible
                        mainAxisSize: MainAxisSize.min,
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
                              icon: const Icon(Icons.edit), iconSize: 20.0,
                              onPressed: () {
                                dialogoEdicion(context,producto);
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
                                dialogoEliminacion(context, producto["id"]);
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
