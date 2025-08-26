import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Providers/productoProvider.dart';
import '../Providers/userProvider.dart';
import '../l10n/app_localizations.dart';
import '../models/productoModel.dart';

class Producto extends StatefulWidget {

  const Producto({super.key});

  @override
  State<Producto> createState() => ProductoState();
}

class ProductoState extends State<Producto> {

  late String userId;

  SupabaseClient database = Supabase.instance.client;

  /*TODO-----------------INITIALIZE-----------------*/
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<UserProvider>().uuid;
      if (uid != null) {
        setState(() {
          userId = uid;
        });
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }
  /*TODO-----------------METODO DE CARGAR-----------------*/
  /// Carga los productos desde la base de datos y los agrupa por supermercado.
  ///
  /// Consulta todos los registros de la tabla 'productos' y los organiza en un mapa,
  /// donde la clave es el nombre del supermercado y el valor es una lista de productos
  /// pertenecientes a ese supermercado. Si un producto no tiene supermercado, se
  /// agrupa bajo 'Sin supermercado'.
  ///
  // /// Actualiza el estado para reflejar los cambios en la interfaz.
  // Future<void> cargarProductos() async {
  //   final productos = await database
  //       .from('productos')
  //       .select()
  //       .eq('usuariouuid', userId); // FILTRAMOS SOLO LOS DEL USUARIO ACTUAL
  //
  //   // MAPA PARA AGRUPAR LOS PRODUCTOS POR NOMBRE DE SUPERMERCADO
  //   final Map<String, List<Map<String, dynamic>>> productosAgrupados = {};
  //
  //   // ITERAMOS SOBRE CADA PRODUCTO OBTENIDO DE LA CONSULTA
  //   for (var producto in productos) {
  //     // OBTENEMOS EL NOMBRE DEL SUPERMERCADO; SI ES NULO, USAMOS 'Sin supermercado'
  //     final supermercado = (producto['supermercado'] ?? 'Sin supermercado').toString();
  //
  //     // SI EL SUPERMERCADO NO EXISTE COMO CLAVE EN EL MAPA, LO AÑADIMOS COMO UNA LISTA VACÍA
  //     productosAgrupados.putIfAbsent(supermercado, () => []);
  //
  //     // AGREGAMOS EL PRODUCTO A LA LISTA CORRESPONDIENTE DENTRO DEL MAPA
  //     productosAgrupados[supermercado]!.add(producto);
  //   }
  //
  //   // ACTUALIZAMOS EL ESTADO CON LOS PRODUCTOS AGRUPADOS PARA REFLEJARLO EN LA INTERFAZ
  //   setState(() {
  //     productosPorSupermercado = productosAgrupados;
  //   });
  // }

  // /*TODO-----------------METODO DE ELIMINAR PRODUCTO-----------------*/
  // /// Elimina un producto de la base de datos según su ID.
  // ///
  // /// Si el producto existe en la tabla 'productos' con el ID proporcionado,
  // /// se elimina y luego se recargan los productos para reflejar los cambios en la UI.
  // ///
  // /// Parámetros:
  // /// - [id]: ID único del producto a eliminar.
  // ///
  // /// Maneja excepciones para evitar fallos durante la operación con la base de datos.
  // Future<void> deleteProducto(int id) async {
  //   try {
  //     await database
  //         .from('productos') // NOMBRE DE LA TABLA
  //         .delete() // OPERACIÓN DELETE
  //         .eq('id', id) // FILTRAMOS POR ID DEL PRODUCTO
  //         .eq('usuariouuid', userId); // Y POR USUARIO ACTUAL
  //
  //     debugPrint('Producto con id $id eliminado exitosamente.');
  //
  //     // RECARGAMOS LOS PRODUCTOS
  //     await cargarProductos();
  //   } catch (e) {
  //     debugPrint('Error al eliminar producto: $e');
  //   }
  // }


  // /*TODO-----------------METODO DE EDITAR PRODUCTO-----------------*/
  // /// Actualiza un producto en la base de datos con los nuevos valores proporcionados.
  // ///
  // /// Parámetros:
  // /// - [producto]: Mapa con los datos actualizados del producto, incluyendo:
  // ///   - 'id': ID único del producto a actualizar.
  // ///   - 'nombre': Nuevo nombre del producto.
  // ///   - 'descripcion': Nueva descripción del producto.
  // ///   - 'precio': Nuevo precio del producto.
  // ///   - 'supermercado': Nuevo supermercado asociado al producto.
  // ///
  // /// Maneja excepciones para evitar fallos durante la operación con la base de datos.
  // Future<void> actualizarProducto(Map<String, dynamic> producto) async {
  //   try {
  //     await database
  //         .from('productos') // NOMBRE DE LA TABLA
  //         .update({
  //       // NUEVOS VALORES A ACTUALIZAR
  //       'nombre': producto['nombre'],
  //       'descripcion': producto['descripcion'],
  //       'precio': producto['precio'],
  //       'supermercado': producto['supermercado'],
  //     })
  //         .eq('id', producto['id']) // PRODUCTO QUE QUEREMOS ACTUALIZAR
  //         .eq('usuariouuid', userId); // DEL USUARIO EN CONCRETO Y NO LOS DEMAS
  //
  //     await cargarProductos();
  //     debugPrint('Producto actualizado correctamente.');
  //   } catch (e) {
  //     debugPrint('Error al actualizar el producto: $e');
  //   }
  // }

  // /*TODO-----------------METODO DE OBTENER TODOS LOS SUPERMERCADOS-----------------*/
  //   // /// Obtiene una lista de todos los supermercados existentes en la base de datos.
  //   // ///
  //   // /// Consulta la tabla 'productos' para extraer los nombres de los supermercados,
  //   // /// eliminando duplicados mediante un 'Set' y convirtiéndolos nuevamente en una lista.
  //   // ///
  //   // /// @return Future<List<String>> Lista de nombres de supermercados sin duplicados.
  //   // Future<List<String>> obtenerSupermercados() async {
  //   //   // CONSULTA PARA OBTENER LOS PRODUCTOS DEL USUARIO ACTUAL
  //   //   final productos = await database
  //   //       .from('productos')
  //   //       .select()
  //   //       .eq('usuariouuid', userId); // FILTRO POR USUARIO
  //   //
  //   //   // EXTRAEMOS LOS SUPERMERCADOS Y ELIMINAMOS DUPLICADOS
  //   //   final supermercados = (productos as List)
  //   //       .map((producto) => producto['supermercado'] as String)
  //   //       .where((s) => s.isNotEmpty) // OPCIONAL: excluir vacíos
  //   //       .toSet()
  //   //       .toList();
  //   //
  //   //   return supermercados;
  //   // }

  /*TODO-----------------DIALOGO DE ELIMINACION DE PRODUCTO-----------------*/
  /// Muestra un cuadro de diálogo de confirmación antes de eliminar un producto.
  ///
  /// Parámetros:
  /// - [context]: Contexto de la aplicación para mostrar el diálogo.
  /// - [idProducto]: ID del producto que se desea eliminar.
  ///
  /// Si el usuario confirma la eliminación, se llama al método 'eliminarProducto(int id) del provider'
  /// y se cierra el diálogo.
  void dialogoEliminacion(BuildContext context, int idProducto) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text( // TITULO DE LA ALERTA
            AppLocalizations.of(context)!.titleConfirmDialog,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          content: Text(
            AppLocalizations.of(context)!.deleteConfirmationP,
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // CERRAMOS EL DIALOGO
                Navigator.of(context).pop();
              },
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                // BORRAMOS EL PRODUCTO
                await context.read<ProductoProvider>().eliminarProducto(idProducto);
                // CERRAMOS EL DIALOGO (ACTUALIZAMOS EN EL METODO)
                Navigator.of(context).pop();
              },
              child: Text(
                AppLocalizations.of(context)!.delete,
                style: const TextStyle(color: Colors.red),
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
  /// - [producto]: Objeto ProductoModel
  ///
  /// Permite modificar el nombre, la descripción, el precio y el supermercado del producto.
  /// Una vez confirmados los cambios, se actualiza el producto en la base de datos.
  void dialogoEdicion(BuildContext context, ProductoModel producto) async {
    // CREAMOS LOS CONTROLADORES PARA LOS TextField Y LOS INICIALIZAMOS CON LOS DATOS DEL PRODUCTO AL QUE HA HECHO CLICK
    final TextEditingController nombreController = TextEditingController(text: producto.nombre);
    final TextEditingController descripcionController = TextEditingController(text: producto.descripcion);
    final TextEditingController precioController = TextEditingController(text: producto.precio.toString());

    // OBTENEMOS LA LISTA DE SUPERMERCADOS QUE EXISTEN
    final List<String> supermercados = await context.read<ProductoProvider>().obtenerSupermercados();

    // INICIALIZAMOS LA LISTA CON EL SUPERMERCADO DEL PRODUCTO SELECCIONADO
    String supermercadoSeleccionado = producto.supermercado;

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

                // CREAMOS EL PRODUCTO ACTUALIZADO
                final productoActualizado = ProductoModel(
                  id: producto.id, // NO LO CAMBIAMOS
                  codBarras: producto.codBarras, // NO LO CAMBIAMOS
                  nombre: nuevoNombre,
                  descripcion: nuevaDescripcion,
                  precio: nuevoPrecio,
                  supermercado: supermercadoSeleccionado,
                  usuarioUuid: producto.usuarioUuid, // NO LO CAMBIAMOS
                  foto: producto.foto, // NO LO CAMBIAMOS
                );

                // LLAMAMOS AL METODO DEL PROVIDER
                await context.read<ProductoProvider>().actualizarProducto(productoActualizado);

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

    final provider = context.read<ProductoProvider>();

    // OBTENEMOS LA LISTA DE LOS SUPERMERCADOS QUE EXISTEN Y AÑADIMOS UNA NUEVA OPCION
    final supermercados = provider.productosPorSupermercado.keys.toList();

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

                    await context.read<ProductoProvider>().crearProducto(
                      nombre: nombre,
                      descripcion: descripcion,
                      precio: precio,
                      supermercado: supermercado,
                      usuarioUuid: context.read<UserProvider>().uuid!, // COGEMOS EL UUID DEL USUARIO
                    );

                    // CERRAMOS EL DIÁLOGO
                    Navigator.of(context).pop();
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
  // Future<void> agregarACompra(int idProducto, double precio, String nombre, String usuarioUUID) async {
  //   try {
  //     // CONSULTA PARA COGER TODOS LOS PRODUCTOS EXISTENTES Y PODER COMPROBAR SI EXISTE
  //     final productosExistentes = await database
  //         .from('compra')
  //         .select()
  //         .eq('idproducto', idProducto)
  //         .eq('usuariouuid', usuarioUUID);
  //
  //     if (productosExistentes.isNotEmpty) {
  //       // SI YA EXISTE, MOSTRAMOS UN MENSAJE DICIENDO QUE YA ESTÁ REGISTRADO
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(AppLocalizations.of(context)!.snackBarRepeatedProduct)),
  //       );
  //     } else {
  //       // SI NO EXISTE, LO AÑADIMOS
  //       await database.from('compra').insert({
  //         'idproducto': idProducto,
  //         'nombre': nombre,
  //         'precio': precio,
  //         'marcado': 0,
  //         'usuariouuid': usuarioUUID,
  //       });
  //
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(AppLocalizations.of(context)!.snackBarAddedProduct)),
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint("${AppLocalizations.of(context)!.snackBarErrorAddingProduct}: $e");
  //   }
  // }



  @override
  Widget build(BuildContext context) {

    final providerProducto = context.watch<ProductoProvider>();
    final productosPorSupermercado = providerProducto.productosPorSupermercado;

    return Scaffold( //BODY PRINCIPAL DE LA PAGINA PRODUCTO
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.products), // TITULO DEL AppBar
        centerTitle: true,
      ),
      body: providerProducto.productos.isEmpty // SI NO HAY PRODUCTOS MOSTRAMOS UN CIRCULO DE CARGA
          ? const Center(
        child: CircularProgressIndicator(),
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
                title: Text(producto.nombre ?? '',style: const TextStyle(fontSize: 16)),
                subtitle: Text(producto.descripcion ?? '',style: const TextStyle(fontSize: 14)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox( // SizedBox PARA TAMAÑO PERSONALIZADO DEL BOTON
                      width: 25,
                      height: 25,
                      child: IconButton(
                        icon: const Icon(Icons.add),
                        iconSize: 20.0,
                        onPressed: () async {
                          try {
                            await context.read<ProductoProvider>().agregarACompra(
                              idProducto: producto.id,
                              precio: producto.precio,
                              nombre: producto.nombre,
                              usuarioUuid: context.read<UserProvider>().uuid!,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.of(context)!.snackBarAddedProduct)),
                            );
                          } catch (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.of(context)!.snackBarRepeatedProduct)),
                            );
                          }
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
                          dialogoEliminacion(context, producto.id);
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
