import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class Producto extends StatefulWidget {
  final Database database;

  const Producto({super.key, required this.database});

  @override
  State<Producto> createState() => ProductoState();
}

class ProductoState extends State<Producto> {
  Map<String, List<Map<String, dynamic>>> productosPorSupermercado = {}; // LISTA PARA GUARDAR LOS PRODUCTOS AGRUPADOS POR 1 SUPERMERCADO EN CONCRETO

  /*TODO-----------------INITIALIZE-----------------*/
  @override
  void initState() {
    super.initState();
    cargarProductos(); // CARGAMOS LOS PRODUCTOS AL ABRIR LA PAGINA PRODUCTOS
  }

  /*TODO-----------------METODO DE CARGAR-----------------*/
  /// Carga los productos desde la base de datos y los agrupa por supermercado.
  ///
  /// Consulta todos los registros de la tabla 'productos' y los organiza en un mapa,
  /// donde la clave es el nombre del supermercado y el valor es una lista de productos
  /// pertenecientes a ese supermercado. Si un producto no tiene supermercado, se
  /// agrupa bajo 'Sin supermercado'.
  ///
  /// Actualiza el estado para reflejar los cambios en la interfaz.
  Future<void> cargarProductos() async {
    // CONSULTA PARA OBTENER TODOS LOS REGISTROS DE LA TABLA 'productos'
    final productos = await widget.database.query('productos');

    // MAPA PARA AGRUPAR LOS PRODUCTOS POR NOMBRE DE SUPERMERCADO
    final Map<String, List<Map<String, dynamic>>> productosAgrupados = {};

    // ITERAMOS SOBRE CADA PRODUCTO OBTENIDO DE LA CONSULTA
    for (var producto in productos) {
      // OBTENEMOS EL NOMBRE DEL SUPERMERCADO; SI ES NULO, USAMOS 'Sin supermercado'
      final supermercado = (producto['supermercado'] ?? 'Sin supermercado').toString();

      // SI EL SUPERMERCADO NO EXISTE COMO CLAVE EN EL MAPA, LO AÑADIMOS AL MAPA COMO UNA LISTA VACÍA
      if (!productosAgrupados.containsKey(supermercado)) {
        productosAgrupados[supermercado] = [];
      }

      // AGREGAMOS EL PRODUCTO A LA LISTA CORRESPONDIENTE DENTRO DEL MAPA
      productosAgrupados[supermercado]?.add(producto);
    }

    // ACTUALIZAMOS EL ESTADO CON LOS PRODUCTOS AGRUPADOS PARA REFLEJARLO EN LA INTERFAZ
    setState(() {
      productosPorSupermercado = productosAgrupados;
    });
  }


  /*TODO-----------------METODO DE ELIMINAR PRODUCTO-----------------*/
  /// Elimina un producto de la base de datos según su ID.
  ///
  /// Si el producto existe en la tabla 'productos' con el ID proporcionado,
  /// se elimina y luego se recargan los productos para reflejar los cambios en la UI.
  ///
  /// Parámetros:
  /// - [id]: ID único del producto a eliminar.
  ///
  /// Maneja excepciones para evitar fallos durante la operación con la base de datos.
  Future<void> deleteProducto(int id) async {
    try {
      await widget.database.delete(
        'productos', // NOMBRE DE LA TABLA
        where: 'id = ?', // CONDICION PARA IDENTIFICAR LO QUE QUEREMOS BORRAR
        whereArgs: [id], // DAMOS VALOR AL ARGUMENTO
      );
      debugPrint('Producto con id $id eliminado exitosamente.');

      // RECARGAMOS LOS PRODUCTOS
      await cargarProductos();
    } catch (e) {
      debugPrint('Error al eliminar producto: $e');
    }
  }

  /*TODO-----------------METODO DE EDITAR PRODUCTO-----------------*/
  /// Actualiza un producto en la base de datos con los nuevos valores proporcionados.
  ///
  /// Parámetros:
  /// - [producto]: Mapa con los datos actualizados del producto, incluyendo:
  ///   - `id`: ID único del producto a actualizar.
  ///   - `nombre`: Nuevo nombre del producto.
  ///   - `descripcion`: Nueva descripción del producto.
  ///   - `precio`: Nuevo precio del producto.
  ///   - `supermercado`: Nuevo supermercado asociado al producto.
  ///
  /// Maneja excepciones para evitar fallos durante la operación con la base de datos.
  Future<void> actualizarProducto(Map<String, dynamic> producto) async {
    try {
      await widget.database.update(
        'productos', // NOMBRE DE LA TABLA
        { // ACTUALIZAMOS LOS DATOS CON EL producto PROPORCIONADO POR PARAMETRO
          'nombre': producto['nombre'],
          'descripcion': producto['descripcion'],
          'precio': producto['precio'],
          'supermercado': producto['supermercado'],
        },
        where: 'id = ?', // CONDICION PARA IDENTIFICAR LO QUE QUEREMOS EDITAR
        whereArgs: [producto['id']], // DAMOS VALOR AL ARGUMENTO
      );
      cargarProductos();
      debugPrint('Producto actualizado exitosamente.');
    } catch (e) {
      debugPrint('Error al actualizar el producto: $e');
    }
  }

  /*TODO-----------------METODO DE OBTENER TODOS LOS SUPERMERCADOS-----------------*/
  /// Obtiene una lista de todos los supermercados existentes en la base de datos.
  ///
  /// Consulta la tabla 'productos' para extraer los nombres de los supermercados,
  /// eliminando duplicados mediante un `Set` y convirtiéndolos nuevamente en una lista.
  ///
  /// @return Future<List<String>> Lista de nombres de supermercados sin duplicados.
  Future<List<String>> obtenerSupermercados() async {
    // CONSULTA PARA OBTENER TODOS LOS REGISTROS DE LA TABLA 'productos'
    final productos = await widget.database.query('productos');

    //OBTENEMOS LOS NOMBRES DE LOS SUPERMERCADOS QUE HAY, LOS TRANSFORMAMOS EN SET PARA
    // ELIMINAR DUPLICADOS Y LO TRANSFORMAMOS EN LISTA OTRA VEZ
    final supermercados = productos.map((producto) => producto['supermercado'] as String).toSet().toList();

    return supermercados;
  }

  /*TODO-----------------DIALOGO DE ELIMINACION DE PRODUCTO-----------------*/
  /// Muestra un cuadro de diálogo de confirmación antes de eliminar un producto.
  ///
  /// Parámetros:
  /// - [context]: Contexto de la aplicación para mostrar el diálogo.
  /// - [idProducto]: ID del producto que se desea eliminar.
  ///
  /// Si el usuario confirma la eliminación, se llama al método `deleteProducto(idProducto)`
  /// y se cierra el diálogo.
  void dialogoEliminacion(BuildContext context, int idProducto) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text( // TITULO DE LA ALERTA
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
                // BORRAMOS EL PRODUCTO
                await deleteProducto(idProducto);
                // CERRAMOS EL DIALOGO (ACTUALIZAMOS EN EL METODO)
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

  /*TODO-----------------DIALOGO DE EDICION DE PRODUCTO-----------------*/
  /// Muestra un cuadro de diálogo para editar un producto.
  ///
  /// Parámetros:
  /// - [context]: Contexto de la aplicación para mostrar el diálogo.
  /// - [producto]: Mapa con los datos actuales del producto a editar.
  ///
  /// Permite modificar el nombre, la descripción, el precio y el supermercado del producto.
  /// Una vez confirmados los cambios, se actualiza el producto en la base de datos.
  void dialogoEdicion(BuildContext context, Map<String, dynamic> producto) async {
    // CREAMOS LOS CONTROLADORES PARA LOS TextField Y LOS INICIALIZAMOS CON LOS DATOS DEL PRODUCTO AL QUE HA HECHO CLICK
    final TextEditingController nombreController = TextEditingController(text: producto['nombre']);
    final TextEditingController descripcionController = TextEditingController(text: producto['descripcion']);
    final TextEditingController precioController = TextEditingController(text: producto['precio'].toString());

    // OBTENEMOS LA LISTA DE SUPERMERCADOS QUE EXISTEN
    final List<String> supermercados = await obtenerSupermercados();

    // INICIALIZAMOS LA LISTA CON EL SUPERMERCADO DEL PRODUCTO SELECCIONADO
    String supermercadoSeleccionado = producto['supermercado'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Editar producto"), // TITULO DE LA ALERTA
          content: Column(
            mainAxisSize: MainAxisSize.min, // PARA QUE VERTICALMENTE, OCUPE LO MINIMO
            children: [
              TextField( // TextField PARA EL NOMBRE
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField( // TextField PARA LA DESCRIPCION
                controller: descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              TextField( // TextField PARA EL PRECIO
                controller: precioController,
                decoration: const InputDecoration(labelText: 'Precio'),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<String>( // DropdownButtonFormField DE Strings
                // PONEMOS DE VALOR, EL SUPERMERCADO DEL PRODUCTO SELECCIONADO
                value: supermercadoSeleccionado,
                decoration: const InputDecoration(labelText: 'Supermercado'),
                // PONEMOS LA LISTA DE SUPERMERCADOS COMO OPCIONES PARA EL DESPLEGABLE
                items: supermercados.map((supermercado) {
                  return DropdownMenuItem<String>( // CADA SUPERMERCADO SE CONVIERTE EN UN DropdownMenuItem
                    value: supermercado,
                    child: Text(supermercado),
                  );
                }).toList(), // CONVERTIDO A LISTA
                // CUANDO EL USUARIO SELECCIONA UNA NUEVA OPCION DE LA LISTA SE EJECUTA EL onChanged
                onChanged: (nuevoSupermercado) {
                  if (nuevoSupermercado != null) { // COMPROBAMOS QUE EL NUEVO VALOR NO SEA NULO
                    supermercadoSeleccionado = nuevoSupermercado; // ACTUALIZAMOS LA VARIABLE CON EL NUEVO SUPERMERCADO
                  }
                },
              ),
            ],
          ),
          actions: [
            // BOTON PARA CANCELAR LA EDICION
            TextButton(
              onPressed: () {
                // CERRAMOS EL DIALOGO
                Navigator.of(context).pop();
              },
              child: const Text("Cancelar"),
            ),
            TextButton( // BOTON PARA CONFIRMAR LA EDICION Y GUARDAR CAMBIOS
              onPressed: () async {
                // COGEMOS LOS DATOS DE LOS CONTROLADORES
                final String nuevoNombre = nombreController.text;
                final String nuevaDescripcion = descripcionController.text;
                final double nuevoPrecio = double.tryParse(precioController.text) ?? 0.0;

                // CREAMOS UN MAPA CON LOS DATOS NUEVOS
                final nuevoProducto = {
                  'id': producto['id'], // MANTENEMOS EL ID DEL PRODUCTO ORIGINAL, ESO NO SE CAMBIA
                  'nombre': nuevoNombre,
                  'descripcion': nuevaDescripcion,
                  'precio': nuevoPrecio,
                  'supermercado': supermercadoSeleccionado,
                };

                // ACTUALIZAMOS EL PRODUCTO
                await actualizarProducto(nuevoProducto);

                // CERRAMOS EL DIALOGO (ACTUALIZAMOS EN EL METODO)
                Navigator.of(context).pop();
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

  /*TODO-----------------DIALOGO DE CREACION DE PRODUCTO-----------------*/
  /// Muestra un cuadro de diálogo para crear un nuevo producto.
  ///
  /// Parámetros:
  /// - [context]: Contexto de la aplicación para mostrar el diálogo.
  ///
  /// Permite ingresar el nombre, la descripción y el precio del producto.
  /// También permite seleccionar un supermercado existente o crear uno nuevo.
  /// Una vez confirmados los datos, el producto se guarda en la base de datos.
  void dialogoCreacion(BuildContext context) {
    // CREAMOS LOS CONTROLADORES PARA LOS TextField
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController descripcionController = TextEditingController();
    final TextEditingController precioController = TextEditingController();
    final TextEditingController nuevoSupermercadoController = TextEditingController();

    // VARIABLES PARA CONTROLAR EL SUPERMERCADO SELECCIONADO Y SI ESTA CREANDO UNO NUEVO
    String? supermercadoSeleccionado;
    bool creandoSupermercado = false;

    // OBTENEMOS LA LISTA DE LOS SUPERMERCADOS QUE EXISTEN Y AÑADIMOS UNA NUEVA OPCION
    final supermercados = productosPorSupermercado.keys.toList();
    supermercados.add("Nuevo supermercado");

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text("Crear producto"), // TÍTULO DEL DIÁLOGO
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // PARA QUE VERTICALMENTE, OCUPE LO MINIMO
                  children: [
                    TextField( // TextField PARA EL NOMBRE
                      controller: nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    TextField( // TextField PARA LA DESCRIPCION
                      controller: descripcionController,
                      decoration: const InputDecoration(labelText: 'Descripción'),
                    ),
                    TextField( // TextField PARA EL PRECIO
                      controller: precioController,
                      decoration: const InputDecoration(labelText: 'Precio'),
                      keyboardType: TextInputType.number,
                    ),
                    DropdownButton<String>( // DropdownButton PARA SELECCIONAR EL SUPERMERCADO
                      isExpanded: true, // OCUPA EL ESPACIO DISPONIBLE
                      value: supermercadoSeleccionado, // VALOR SELECCIONADO INICIALMENTE
                      hint: const Text("Seleccionar supermercado"),
                      items: supermercados.map((supermercado) {
                        // PONEMOS LA LISTA DE SUPERMERCADOS COMO OPCIONES PARA EL DESPLEGABLE
                        return DropdownMenuItem<String>( // CADA SUPERMERCADO SE CONVIERTE EN UN DropdownMenuItem
                          value: supermercado,
                          child: Text(supermercado),
                        );
                      }).toList(), // CONVERTIDO A LISTA
                      // CUANDO EL USUARIO SELECCIONA UNA NUEVA OPCION DE LA LISTA SE EJECUTA EL onChanged
                      onChanged: (String? value) {
                        setState(() {
                          // ACTUALIZAMOS EL SUPERMERCADO SELECCIONADO
                          supermercadoSeleccionado = value;
                          // ACTIVAR CAMPO EXTRA SI ES "Nuevo supermercado"
                          creandoSupermercado = (value == "Nuevo supermercado");
                        });
                      },
                    ),
                    // CAMPO PARA CREAR UN NUEVO SUPERMERCADO (VISIBLE SOLO SI SE SELECCIONÓ "Nuevo supermercado")
                    if (creandoSupermercado)
                      TextField(
                        controller: nuevoSupermercadoController,
                        decoration: const InputDecoration(labelText: 'Nombre del nuevo supermercado'),
                      ),
                  ],
                ),
              ),
              actions: [
                // BOTON PARA CANCELAR LA EDICION
                TextButton(
                  onPressed: () {
                    // CERRAMOS EL DIALOGO
                    Navigator.of(context).pop();
                  },
                  child: const Text("Cancelar"),
                ),
                // BOTON PARA CONFIRMAR LA CREACION Y GUARDAR CAMBIOS
                TextButton(
                  onPressed: () async {
                    // VALIDAMOS LOS CAMPOS
                    final String nombre = nombreController.text;
                    final String descripcion = descripcionController.text;
                    final double precio = double.tryParse(precioController.text) ?? 0.0;
                    final String supermercado = creandoSupermercado
                        ? nuevoSupermercadoController.text // USAMOS EL NUEVO SUPERMERCADO
                        : supermercadoSeleccionado ?? ''; // USAMOS EL SELECCIONADO

                    // COMPROBAMOS QUE LOS CAMPOS REQUERIDOS NO ESTÉN VACÍOS
                    if (nombre.isEmpty || supermercado.isEmpty) {
                      debugPrint("Nombre o supermercado no pueden estar vacíos");
                      return;
                    }

                    // CREAR EL NUEVO PRODUCTO
                    final nuevoProducto = {
                      'nombre': nombre,
                      'descripcion': descripcion,
                      'precio': precio,
                      'supermercado': supermercado,
                    };

                    // INSERTAMOS EL PRODUCTO EN LA BASE DE DATOS
                    await widget.database.insert('productos', nuevoProducto);

                    // CERRAMOS EL DIÁLOGO Y RECARGAMOS LA LISTA DE PRODUCTOS
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
  /// Agrega un producto a la lista de compra en la base de datos.
  ///
  /// Si el producto ya existe en la lista, muestra un mensaje
  /// informando al usuario. En caso contrario, lo añade como no marcado.
  ///
  /// Parámetros:
  /// - [idProducto]: ID único del producto.
  /// - [precio]: Precio del producto.
  /// - [nombre]: Nombre del producto.
  ///
  /// Maneja excepciones para evitar fallos durante la operación con la base de datos.
  Future<void> agregarACompra(int idProducto, double precio, String nombre) async {
    try {
      // CONSUTLA PARA COGER TODOS LOS PRODUCTOS EXISTENTES Y PODER COMPROBAR SI EXISTE
      final productosExistentes = await widget.database.rawQuery(
        'SELECT * FROM compra WHERE idProducto = ?',
        [idProducto],
      );

      if (productosExistentes.isNotEmpty) {
        // SI YA EXISTE, MOSTRAMOS UN MENSAJE DICIENDO QUE YA ESTA REGISTRADO
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este producto ya está en la lista de compra.')),
        );
      } else {
        // SI NO EXISTE, LO AÑADIMOS
        await widget.database.insert(
          'compra', // NOMBRE DE LA TABLA
          {
            'idProducto': idProducto,
            'nombre': nombre,
            'precio': precio,
            'marcado': 0, // POR DEFECTO SE GUARDA COMO NO MARCADO
          },
          //conflictAlgorithm: ConflictAlgorithm.replace, SI EL ID DEL PRODUCTO A GUARDAR COINCIDE CON OTRO EXISTENTE, LO REEMPLAZA
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
    return Scaffold( //BODY PRINCIPAL DE LA PAGINA PRODUCTO
      appBar: AppBar(
        title: const Text("Productos"), // TITULO DEL AppBar
        centerTitle: true,
      ),
      body: productosPorSupermercado.isEmpty // SI NO HAY PRODUCTOS MOSTRAMOS ESTE MENSAJE
          ? const Center(
        child: Text(
          "No hay productos disponibles",
          style: TextStyle(
            color: Color(0xFF212121), // GRIS OSCURO PARA EL TEXTO
            fontSize: 18,
          ),
        ),
      )
          : ListView( // SI HAY PRODUCTOS, MOSTRAMOS UNA LISTA
        children: productosPorSupermercado.entries.map((entry) {
          final supermercado = entry.key; // AQUI OBTENEMOS EL NOMBRE DEL SUPERMERCADO
          final productos = entry.value; // AQUI OBTENEMOS LA LISTA DE PRODUCTOS DE ESE SUPERMERCADO

          return ExpansionTile(  // CARPETA EXPANSIBLE PARA GUARDAR CADA LISTA DE PRODUCTOS
            title: Text(
              supermercado,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            children: productos.map((producto) { // LISTA DE PRODUCTOS DE CADA SUPERMERCADO (producto es el producto actual)
              return ListTile( // CADA PRODUCTO SE MUESTRA COMO UN ListTile
                leading: const Icon(Icons.fastfood),
                title: Text(producto['nombre'] ?? ''),
                subtitle: Text(producto['descripcion'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox( // SizedBox PARA TAMAÑO PERSONALIZADO DEL BOTON
                      width: 25,
                      height: 25,
                      child: IconButton(
                        icon: const Icon(Icons.add),
                        iconSize: 20.0,
                        onPressed: () {
                           // AGREGAMOS EL PRODUCTO A LA TABLA COMPRA
                          agregarACompra(producto['id'], producto['precio'], producto['nombre']);
                        },
                        padding: EdgeInsets.zero, // QUITAMOS EL ESPACIO EXTRA
                      ),
                    ),
                    SizedBox( // SizedBox PARA TAMAÑO PERSONALIZADO DEL BOTON
                      width: 25,
                      height: 25,
                      child: IconButton(
                        icon: const Icon(Icons.edit),
                        iconSize: 20.0,
                        onPressed: () {
                          // ABRIMOS EL DIALOGO DE ELIMINACION Y LE PASAMOS EL CONTEXTO
                          // Y EL PRODUCTO EN EL QUE HEMOS HECHO CLICK
                          dialogoEdicion(context, producto);
                        },
                        padding: EdgeInsets.zero, // QUITAMOS EL ESPACIO EXTRA
                      ),
                    ),
                    SizedBox( // SizedBox PARA TAMAÑO PERSONALIZADO DEL BOTON
                      width: 25,
                      height: 25,
                      child: IconButton(
                        icon: const Icon(Icons.delete),
                        iconSize: 20.0,
                        onPressed: () {
                          // ABRIMOS EL DIALOGO DE ELIMINACION Y LE PASAMOS EL CONTEXTO
                          // Y EL ID DEL PRODUCTO EN EL QUE HEMOS HECHO CLICK
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
      floatingActionButton: FloatingActionButton( // BOTON FLOTANTE PARA AÑADIR NUEVO PRODUCTO
        onPressed: () {
          // ABRIMOS EL DIALOGO DE CREACION
          dialogoCreacion(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
