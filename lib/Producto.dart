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

  /*TODO-----------------METODO DE ELIMINAR PRODUCTO-----------------*/
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

  /*TODO-----------------METODO DE EDITAR PRODUCTO-----------------*/
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

  /*TODO-----------------METODO DE OBTENER TODOS LOS SUPERMERCADOS-----------------*/
  Future<List<String>> obtenerSupermercados() async {
    final productos = await widget.database.query('productos');
    final supermercados = productos.map((producto) => producto['supermercado'] as String).toSet().toList();
    return supermercados;
  }

  /*TODO-----------------DIALOGO DE ELIMINACION DE PRODUCTO-----------------*/
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

  /*TODO-----------------DIALOGO DE EDICION DE PRODUCTO-----------------*/
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

  /*TODO-----------------DIALOGO DE CREACION DE PRODUCTO-----------------*/
  void dialogoCreacion(BuildContext context) {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController descripcionController = TextEditingController();
    final TextEditingController precioController = TextEditingController();
    final TextEditingController nuevoSupermercadoController = TextEditingController();

    String? supermercadoSeleccionado;
    bool creandoSupermercado = false; // Para controlar si se muestra el TextField

    // Obtener supermercados únicos
    final supermercados = _productosPorSupermercado.keys.toList();
    supermercados.add("Nuevo supermercado"); // Agregar opción para crear

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text("Crear producto"),
              content: SingleChildScrollView(
                child: Column(
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
                    DropdownButton<String>(
                      isExpanded: true,
                      value: supermercadoSeleccionado,
                      hint: const Text("Seleccionar supermercado"),
                      items: supermercados.map((supermercado) {
                        return DropdownMenuItem<String>(
                          value: supermercado,
                          child: Text(supermercado),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          supermercadoSeleccionado = value;
                          creandoSupermercado = (value == "Nuevo supermercado");
                        });
                      },
                    ),
                    if (creandoSupermercado)
                      TextField(
                        controller: nuevoSupermercadoController,
                        decoration: const InputDecoration(labelText: 'Nombre del nuevo supermercado'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Cerrar diálogo
                  },
                  child: const Text("Cancelar"),
                ),
                TextButton(
                  onPressed: () async {
                    // Validar los campos
                    final String nombre = nombreController.text;
                    final String descripcion = descripcionController.text;
                    final double precio = double.tryParse(precioController.text) ?? 0.0;
                    final String supermercado = creandoSupermercado
                        ? nuevoSupermercadoController.text
                        : supermercadoSeleccionado ?? '';

                    if (nombre.isEmpty || supermercado.isEmpty) {
                      debugPrint("Nombre o supermercado no pueden estar vacíos");
                      return;
                    }

                    // Crear el nuevo producto
                    final nuevoProducto = {
                      'nombre': nombre,
                      'descripcion': descripcion,
                      'precio': precio,
                      'supermercado': supermercado,
                    };

                    // Insertar el producto en la base de datos
                    await widget.database.insert('productos', nuevoProducto);

                    // Cerrar el diálogo y recargar productos
                    Navigator.of(context).pop();
                    cargarProductos();
                  },
                  child: const Text("Guardar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

/*TODO-----------------METODO AÑADIR PRODUCTO A LISTA DE LA COMPRA-----------------*/
  Future<void> _agregarACompra(int idProducto, double precio, String nombre) async {
    try {
      // Verificar si el producto ya está en la tabla compra
      final productosExistentes = await widget.database.rawQuery(
        'SELECT * FROM compra WHERE idProducto = ?', [idProducto],
      );

      if (productosExistentes.isNotEmpty) {
        // Si ya existe, mostramos un mensaje diciendo que ya está en la lista
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este producto ya está en la lista de compra.')),
        );
      } else {
        // Si no existe, lo añadimos
        await widget.database.insert(
          'compra',
          {
            'idProducto': idProducto,
            'nombre': nombre,
            'precio': precio,
            'marcado': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto añadido a la lista de compra')),
        );
      }
    } catch (e) {
      debugPrint('Error al añadir producto a la lista de compra: $e');
    }
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
            title: Text(supermercado,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 25,
                      height: 25,
                      child: IconButton(
                        icon: const Icon(Icons.add),
                        iconSize: 20.0,
                        onPressed: () {
                          _agregarACompra(producto['id'], producto['precio'], producto['nombre']);
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    SizedBox(
                      width: 25,
                      height: 25,
                      child: IconButton(
                        icon: const Icon(Icons.edit),
                        iconSize: 20.0,
                        onPressed: () {
                          dialogoEdicion(context, producto);
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    SizedBox(
                      width: 25,
                      height: 25,
                      child: IconButton(
                        icon: const Icon(Icons.delete),
                        iconSize: 20.0,
                        onPressed: () {
                          dialogoEliminacion(context, producto['id']);
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          dialogoCreacion(context);
        },
        child: const Icon(Icons.add),
      ),
    );

  }
}
