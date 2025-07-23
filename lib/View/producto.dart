import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Producto extends StatefulWidget {

  const Producto({super.key});

  @override
  State<Producto> createState() => ProductoState();
}

class ProductoState extends State<Producto> {

  SupabaseClient database = Supabase.instance.client;

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
    final productos = await database
        .from('productos')
        .select();


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
      await database
          .from('productos') // NOMBRE DE LA TABLA
          .delete() // OPERACIÓN DELETE
          .eq('id', id); // CONDICIÓN PARA IDENTIFICAR LO QUE QUEREMOS BORRAR

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
  ///   - 'id': ID único del producto a actualizar.
  ///   - 'nombre': Nuevo nombre del producto.
  ///   - 'descripcion': Nueva descripción del producto.
  ///   - 'precio': Nuevo precio del producto.
  ///   - 'supermercado': Nuevo supermercado asociado al producto.
  ///
  /// Maneja excepciones para evitar fallos durante la operación con la base de datos.
  Future<void> actualizarProducto(Map<String, dynamic> producto) async {
    try {
      await database
          .from('productos') // NOMBRE DE LA TABLA
          .update({ // ACTUALIZAMOS LOS DATOS CON EL producto PROPORCIONADO POR PARÁMETRO
        'nombre': producto['nombre'],
        'descripcion': producto['descripcion'],
        'precio': producto['precio'],
        'supermercado': producto['supermercado'],
      })
          .eq('id', producto['id']); // CONDICIÓN PARA IDENTIFICAR LO QUE QUEREMOS EDITAR

      await cargarProductos();
      debugPrint('Producto actualizado exitosamente.');
    } catch (e) {
      debugPrint('Error al actualizar el producto: $e');
    }
  }


  /*TODO-----------------METODO DE OBTENER TODOS LOS SUPERMERCADOS-----------------*/
  /// Obtiene una lista de todos los supermercados existentes en la base de datos.
  ///
  /// Consulta la tabla 'productos' para extraer los nombres de los supermercados,
  /// eliminando duplicados mediante un 'Set' y convirtiéndolos nuevamente en una lista.
  ///
  /// @return Future<List<String>> Lista de nombres de supermercados sin duplicados.
  Future<List<String>> obtenerSupermercados() async {
    // CONSULTA PARA OBTENER TODOS LOS REGISTROS DE LA TABLA 'productos'
    final productos = await database
        .from('productos')
        .select();

    // OBTENEMOS LOS NOMBRES DE LOS SUPERMERCADOS QUE HAY, LOS TRANSFORMAMOS EN SET PARA
    // ELIMINAR DUPLICADOS Y LO TRANSFORMAMOS EN LISTA OTRA VEZ
    final supermercados = (productos as List)
        .map((producto) => producto['supermercado'] as String)
        .toSet()
        .toList();

    return supermercados;
  }


  /*TODO-----------------DIALOGO DE ELIMINACION DE PRODUCTO-----------------*/
  /// Muestra un cuadro de diálogo de confirmación antes de eliminar un producto.
  ///
  /// Parámetros:
  /// - [context]: Contexto de la aplicación para mostrar el diálogo.
  /// - [idProducto]: ID del producto que se desea eliminar.
  ///
  /// Si el usuario confirma la eliminación, se llama al método 'deleteProducto(idProducto)'
  /// y se cierra el diálogo.
  void dialogoEliminacion(BuildContext context, int idProducto) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text( // TITULO DE LA ALERTA
            AppLocalizations.of(context)!.titleConfirmDialog,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          content: Text(
            AppLocalizations.of(context)!.deleteConfirmationP,
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // CERRAMOS EL DIALOGO
                Navigator.of(context).pop();
              },
              child: Text(
                AppLocalizations.of(context)!.cancel,
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
              child: Text(
                AppLocalizations.of(context)!.delete,
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
          title:Text(AppLocalizations.of(context)!.editProduct), // TITULO DE LA ALERTA
          content: Column(
            mainAxisSize: MainAxisSize.min, // PARA QUE VERTICALMENTE, OCUPE LO MINIMO
            children: [
              TextField( // TextField PARA EL NOMBRE
                controller: nombreController,
                decoration:  InputDecoration(labelText:AppLocalizations.of(context)!.name),
              ),
              TextField( // TextField PARA LA DESCRIPCION
                controller: descripcionController,
                decoration: InputDecoration(labelText:AppLocalizations.of(context)!.description),
              ),
              TextField( // TextField PARA EL PRECIO
                controller: precioController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.price),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<String>( // DropdownButtonFormField DE Strings
                // PONEMOS DE VALOR, EL SUPERMERCADO DEL PRODUCTO SELECCIONADO
                value: supermercadoSeleccionado,
                decoration: InputDecoration(labelText:AppLocalizations.of(context)!.supermarket),
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
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton( // BOTON PARA CONFIRMAR LA EDICION Y GUARDAR CAMBIOS
              onPressed: () async {
                // COGEMOS LOS DATOS DE LOS CONTROLADORES
                final String nuevoNombre = nombreController.text;
                final String nuevaDescripcion = descripcionController.text;
                final double nuevoPrecio = double.tryParse(precioController.text) ?? 0.0;

                // if (nuevoNombre.isEmpty || supermercadoSeleccionado.isEmpty) {
                //   ScaffoldMessenger.of(context).showSnackBar(
                //     SnackBar(content: Text(AppLocalizations.of(context)!.snackBarInvalidData)),
                //   );
                //   return;
                // } TODO

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
              child:Text(AppLocalizations.of(context)!.save),
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
    supermercados.add(AppLocalizations.of(context)!.selectSupermarketNameDDB);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.createProduct), // TÍTULO DEL DIÁLOGO
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // PARA QUE VERTICALMENTE, OCUPE LO MINIMO
                  children: [
                    TextField( // TextField PARA EL NOMBRE
                      controller: nombreController,
                      decoration:  InputDecoration(labelText: AppLocalizations.of(context)!.name),
                    ),
                    TextField( // TextField PARA LA DESCRIPCION
                      controller: descripcionController,
                      decoration:  InputDecoration(labelText: AppLocalizations.of(context)!.description),
                    ),
                    TextField( // TextField PARA EL PRECIO
                      controller: precioController,
                      decoration:  InputDecoration(labelText: AppLocalizations.of(context)!.price),
                      keyboardType: TextInputType.number,
                    ),
                    DropdownButton<String>( // DropdownButton PARA SELECCIONAR EL SUPERMERCADO
                      isExpanded: true, // OCUPA EL ESPACIO DISPONIBLE
                      value: supermercadoSeleccionado, // VALOR SELECCIONADO INICIALMENTE
                      hint: Text(AppLocalizations.of(context)!.selectSupermarket),
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
                          creandoSupermercado = (value == "Nuevo supermercado" || value == "New supermarket");
                        });
                      },
                    ),
                    // CAMPO PARA CREAR UN NUEVO SUPERMERCADO (VISIBLE SOLO SI SE SELECCIONÓ "Nuevo supermercado")
                    if (creandoSupermercado)
                      TextField(
                        controller: nuevoSupermercadoController,
                        decoration: InputDecoration(labelText: AppLocalizations.of(context)!.selectSupermarketName),
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
                  child: Text(AppLocalizations.of(context)!.cancel),
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
                    await database
                        .from('productos') // NOMBRE DE LA TABLA
                        .insert(nuevoProducto); // INSERTAMOS EL NUEVO PRODUCTO

                    // CERRAMOS EL DIÁLOGO Y RECARGAMOS LA LISTA DE PRODUCTOS
                    Navigator.of(context).pop();
                    cargarProductos();
                  },
                  child: Text(AppLocalizations.of(context)!.save),
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
      // CONSULTA PARA COGER TODOS LOS PRODUCTOS EXISTENTES Y PODER COMPROBAR SI EXISTE
      final productosExistentes = await database
          .from('compra')
          .select()
          .eq('idproducto', idProducto);

      if (productosExistentes.isNotEmpty) {
        // SI YA EXISTE, MOSTRAMOS UN MENSAJE DICIENDO QUE YA ESTÁ REGISTRADO
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.snackBarRepeatedProduct)),
        );
      } else {
        // SI NO EXISTE, LO AÑADIMOS
        await database
            .from('compra') // NOMBRE DE LA TABLA
            .insert({
          'idproducto': idProducto,
          'nombre': nombre,
          'precio': precio,
          'marcado': 0, // POR DEFECTO SE GUARDA COMO NO MARCADO
        });
        // conflictAlgorithm: ConflictAlgorithm.replace, NO APLICA EN SUPABASE PERO SE PUEDE MANEJAR POR POLÍTICAS DE CONFLICTO SI SE NECESITA

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.snackBarAddedProduct)),
        );
      }
    } catch (e) {
      debugPrint("${AppLocalizations.of(context)!.snackBarErrorAddingProduct}: $e");
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold( //BODY PRINCIPAL DE LA PAGINA PRODUCTO
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.products), // TITULO DEL AppBar
        centerTitle: true,
      ),
      body: productosPorSupermercado.isEmpty // SI NO HAY PRODUCTOS MOSTRAMOS ESTE MENSAJE
          ? const Center(
        child: Text(
          "No hay productos disponibles",
          style: TextStyle(
            color: Color(0xFF212121), // GRIS OSCURO PARA EL TEXTO
            fontSize: 16,
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
                fontSize: 18,
              ),
            ),
            children: productos.map((producto) { // LISTA DE PRODUCTOS DE CADA SUPERMERCADO (producto es el producto actual)
              return ListTile( // CADA PRODUCTO SE MUESTRA COMO UN ListTile
                leading: const Icon(Icons.fastfood),
                title: Text(producto['nombre'] ?? '',style: TextStyle(fontSize: 16)),
                subtitle: Text(producto['descripcion'] ?? '',style: TextStyle(fontSize: 14)),
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
                          agregarACompra(producto['id'], (producto['precio'] as num).toDouble(), producto['nombre']);
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
