import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/themeProvider.dart';
import '../Providers/userProvider.dart';
import '../l10n/app_localizations.dart';


class Compra extends StatefulWidget {

  const Compra({super.key});

  @override
  State<Compra> createState() => CompraState();
}

class CompraState extends State<Compra> {

  SupabaseClient database = Supabase.instance.client;

  // LISTA PARA ALMACENAR LOS PRODUCTOS AGRUPADOS POR SUPERMERCADO
  List<Map<String, dynamic>> productosCompra = [];

  // LISTA PARA ALMACENAR LOS PRODUCTOS Y CAMBIAR VALORES
  List<Map<String, dynamic>> productosMutables = [];

  // VARIABLE PARA ALMACENAR EL PRECIO TOTAL DE LOS PRODUCTOS MARCADOS
  double precioTotalCompra = 0.0;

  @override
  void initState() {
    super.initState();
    // CARGAR LOS PRODUCTOS Y CALCULAR EL TOTAL DE LOS PRODUCTOS MARCADOS AL INICIAR
    cargarCompra();
  }

  /*TODO-----------------METODO DE CARGAR COMPRA-----------------*/
  /// Carga los productos de la compra y los agrupa por supermercado.
  ///
  /// - Obtiene los productos desde la base de datos.
  /// - Convierte la lista inmutable en mutable para facilitar modificaciones.
  /// - Agrupa los productos por supermercado.
  /// - Calcula el total de los productos marcados.
  /// - Actualiza el estado para reflejar los cambios en la interfaz.
  Future<void> cargarCompra() async {
    // CONSULTA QUE OBTIENE LOS PRODUCTOS DE LA COMPRA, JUNTO CON EL SUPERMERCADO DE CADA PRODUCTO
    final response = await database
        .from('compra')
        .select('*, productos(supermercado)')
        .eq('usuariouuid', context.read<UserProvider>().uuid!);

    // response ya es la lista de datos (no viene envuelto en objeto con .data)
    final productosInmutables = (response as List).cast<Map<String, dynamic>>();

    // TRANSFORMAMOS LA LISTA INMUTABLE PARA PODER MODIFICARLA
    productosMutables = productosInmutables.map((producto) {
      return Map<String, dynamic>.from(producto);
    }).toList();

    // AGRUPAMOS LOS PRODUCTOS POR SUPERMERCADO
    final Map<String, List<Map<String, dynamic>>> agrupados = {};

    for (var producto in productosMutables) {
      final supermercado = (producto['productos']?['supermercado'] ?? 'Sin supermercado').toString();

      if (producto['marcado'] == 1) {
        precioTotalCompra += producto["precio"] * producto["cantidad"];
      }

      if (!agrupados.containsKey(supermercado)) {
        agrupados[supermercado] = [];
      }
      agrupados[supermercado]?.add(producto);
    }

    // ACTUALIZAMOS EL ESTADO CON LOS PRODUCTOS AGRUPADOS PARA LA INTERFAZ
    setState(() {
      productosCompra = agrupados.entries.map((entry) {
        return {
          'supermercado': entry.key,
          'productos': entry.value,
        };
      }).toList();
    });
  }


  /// Aumenta la cantidad de un producto en la compra en 1
  ///
  /// - Realiza una consulta SQL para incrementar la cantidad de un producto específico
  ///   identificado por 'idProducto' en la base de datos.
  Future<void> sumar1Cantidad(int idProducto) async {
    try {
      // LLAMAMOS A LA FUNCION SQL QUE INCREMENTA LA CANTIDAD DEL PRODUCTO
      await database.rpc('incrementar_cantidad', params: {
        'p_id_producto': idProducto,
        'p_usuario_uuid': context.read<UserProvider>().uuid,
      });

    } catch (e) {
      debugPrint('Error al incrementar la cantidad: $e');
    }
  }



  /// Disminuye la cantidad de un producto en la compra en 1
  ///
  /// - Realiza una consulta SQL para disminuir la cantidad de un producto específico
  ///   identificado por 'idProducto' en la base de datos.
  Future<void> restar1Cantidad(int idProducto) async {
    try {
      await database.rpc('restar_cantidad', params: {
        'p_id_producto': idProducto,
        'p_usuario_uuid': context.read<UserProvider>().uuid,
      });

    } catch (e) {
      debugPrint('Error al decrementar la cantidad: $e');
    }
  }


  /// Desmarca todos los productos que estaban marcados (cambia `marcado` de 1 a 0)
  /// y resetea la cantidad de **todos** los productos a 1.
  ///
  /// Esto simula un reseteo general donde se limpia la selección y se establecen
  /// las cantidades por defecto a 1, independientemente de su estado previo.
  Future<void> resetearProductosListaCompra() async {
    try {
      await database.rpc('resetear_productos_lista_compra', params: {
        'p_usuario_uuid': context.read<UserProvider>().uuid,
      });

      debugPrint('Lista de la compra reseteada');
    } catch (e) {
      debugPrint('Error al resetear productos: $e');
    }
  }



  /*TODO-----------------METODO GENERAR FACTURA-----------------*/
  /// Genera una factura con los productos marcados
  ///
  /// - Obtiene los productos marcados en la lista de compra.
  /// - Si no hay productos marcados, muestra un mensaje de error al usuario.
  /// - Calcula el precio total de los productos marcados.
  /// - Crea una nueva factura en la base de datos con el total calculado.
  /// - Inserta los productos correspondientes a la factura en la tabla 'producto_factura'.
  /// - Muestra un mensaje de confirmación al usuario.
  ///
  /// Si el proceso es exitoso, la factura se genera correctamente con los productos seleccionados.
  Future<void> generarFactura() async {

    try {
      final userId = context.read<UserProvider>().uuid!;

      // CONSULTA PARA OBTENER TODOS LOS PRODUCTOS MARCADOS
      final response = await database
          .from('compra')
          .select()
          .eq('marcado', 1)
          .eq('usuariouuid', userId);

      final productosMarcados = response as List<dynamic>?;

      // SI NO HAY RESULTADOS EN LA CONSULTA MOSTRAMOS UN MENSAJE DE ERROR
      if (productosMarcados == null || productosMarcados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.snackBarReceiptQuantityError)),
        );
        return;
      }

      // CALCULAMOS EL PRECIO TOTAL DE LOS PRODUCTOS MARCADOS
      double precioTotal = productosMarcados.fold(0.0, (sum, producto) {
        return sum +
            (producto['precio'] as num).toDouble() *
                (producto['cantidad'] as num).toDouble();
      });

      // OBTENEMOS SOLO LA FECHA DEL DateTime.now
      final fechaString = DateTime.now().toIso8601String().split('T')[0];

      // PARSEAMOS A UN FORMATO CON SENTIDO PARA EL 90% DE LA POBLACION
      final fechaActual = DateFormat("dd/MM/yyyy").format(DateTime.parse(fechaString));

      // OBTENEMOS EL idProducto DEL PRIMER PRODUCTO MARCADO
      final int idPrimero = productosMarcados.first['idproducto'];

      // CONSULTAMOS EL SUPERMERCADO DE ESE PRODUCTO DESDE LA TABLA productos
      final respuestaSupermercado = await database
          .from('productos')
          .select('supermercado')
          .eq('id', idPrimero)
          .single();

      final supermercado = respuestaSupermercado['supermercado'] ?? 'Supermercado Desconocido';


      // INSERTAMOS LA NUEVA FACTURA Y OBTENEMOS SU ID
      final insertFactura = await database.from('facturas').insert({
        'precio': precioTotal,
        'fecha': fechaActual,
        'supermercado': supermercado,
        'usuariouuid': context.read<UserProvider>().uuid!,
      }).select().single();

      final idFactura = insertFactura['id'];

      // ITERAMOS SOBRE CADA PRODUCTO MARCADO PARA INSERTARLO EN LA TABLA producto_factura
      for (var producto in productosMarcados) {
        await database.from('producto_factura').insert({
          'idproducto': producto['idproducto'],
          'idfactura': idFactura,
          'cantidad': producto['cantidad'],
          'preciounidad': producto['precio'],
          'total': (producto['precio'] as num).toDouble() *
              (producto['cantidad'] as num).toDouble(),
          'usuariouuid': userId,
        });
      }

      // DESMARCAMOS TODOS LOS PRODUCTOS Y RECARGAMOS
      await resetearProductosListaCompra();
      await cargarCompra();

      // MOSTRAMOS MENSAJE DE CONFIRMACION
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.snackBarAddedReceipt)),
      );
    } catch (e) {
      debugPrint('Error al generar factura: $e');
    }
  }



  /*TODO-----------------DIALOGO DE ELIMINACION DE PRODUCTO EN LISTA-----------------*/
  /// Muestra un cuadro de diálogo de confirmacion antes de eliminar un producto de la lista de la compra
  ///
  /// Si el usuario confirma la eliminación, llama al método 'deleteProducto(idProducto)' y luego
  /// actualizarPrecio(idProducto,precio,cantidad) para actualizar el precio de los productos marcados
  ///
  /// Maneja excepciones para evitar fallos durante la operación con la base de datos.
  void dialogoEliminacion(BuildContext context, int idProducto,double precio, int cantidad) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text( // TITULO DE LA ALERTA
            AppLocalizations.of(context)!.titleConfirmDialog,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            AppLocalizations.of(context)!.deleteConfirmationSP,
            style: TextStyle(fontSize: 16),
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
                await deleteProducto(idProducto);
                actualizarPrecio(idProducto,precio,cantidad);
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
  // METODO PARA ELIMINAR PRODUCTO DE LA LISTA DE LA COMPRA

  /// Elimina un producto de la lista de la compra según su ID.
  /// identificado por 'idProducto' en la base de datos.
  Future<void> deleteProducto(int idProducto) async {
    try {
    await database
        .from('compra')
        .delete()
        .eq('idproducto', idProducto)
        .eq('usuariouuid', context.read<UserProvider>().uuid!);
    } catch (e) {
      debugPrint('Error al borrar producto: $e');
    }
  }


  /// Actualiza el precio de los productos marcados
  ///
  /// Parámetros:
  /// - idProducto: ID único del producto a eliminar.
  /// - precio: precio del producto para restarlo del total
  /// - cantidad: cantidad del producto para restar el precio total de manera acorde
  void actualizarPrecio(int idProducto, double precio, int cantidad) {
    // ELIMINAMOS EL PRODUCTO DE LA LISTA EN MEMORIA (PARA NO PERDER PRODUCTOS MARCADOS)
    setState(() {
      precioTotalCompra -= precio * cantidad; // RESTAMOS EL PRECIO TOTAL DEL PRODUCTO ELIMINADO

      // COGEMOS EL SUPERMERCADO DE ESE PRODUCTO (firstWhere DEVUELVE LA PRIMERA COINCIDENCIA)
      final supermercado = productosCompra.firstWhere(
              (supermercado) => supermercado['productos'].any((p) => p['idproducto'] == idProducto)
      );

      // BORRAMOS EL PRODUCTO DE ESE SUPERMERCADO
      supermercado['productos'].removeWhere((p) => p['idproducto'] == idProducto);

      // COMPROBAMOS SI EL SUPERMERCADO SIGUE TENIENDO PRODUCTOS, SI NO TIENE, LO BORRAMOS
      if (supermercado['productos'].isEmpty) {
        productosCompra.remove(supermercado);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((AppLocalizations.of(context)!.shoppingList)), // TITULO DEL AppBar
        centerTitle: true,
        actions: [
          IconButton( // ICONO PARA GENERAR FACTURAS
            icon: const Icon(Icons.receipt),
            onPressed: generarFactura,
            tooltip: (AppLocalizations.of(context)!.generateReceipt),
          ),
        ],
      ),
      body: productosCompra.isEmpty ? const Center(
        child: CircularProgressIndicator(),
      ) :
      Column(
        children: [
          Expanded( // EXPANDED PARA QUE EL ListView.Builder NO DE ERROR
            child: ListView.builder(
              // TAMAÑO EN BASE A LA CANTIDAD DE SUPERMERCADOS QUE HAY
              itemCount: productosCompra.length,
              itemBuilder: (context, index) {
                // OBTENEMOS UN ELEMENTO DE LA LISTA BASANDONOS EN EL INDICE
                final grupo = productosCompra[index];
                // OBTENEMOS EL SUPERMERCADO DE ESE ELEMENTO
                final supermercado = grupo['supermercado'];
                // OBTENEMOS LA LISTA DE PRODUCTOS DE ESE SUPERMERCADO
                final productos = grupo['productos'] as List<Map<String, dynamic>>;

                return ExpansionTile( // "CARPETAS"
                  title: Text(supermercado,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  children: productos.map((producto) {
                    return ListTile(
                      visualDensity: const VisualDensity(horizontal: -4), // HACE QUE HAYA MENOS ESPACIO ENTRE EL LEADING Y EL TITLE
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4), // REDUCE EL PADDING LATERAL
                      leading: IconButton( // BOTON PARA MARCAR Y DESMARCAR PRODUCTO
                        icon: Icon( // SI producto['marcado'] ES 1, PONEMOS UN ESTILO Y SI NO, OTRO
                          producto['marcado'] == 1
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: producto['marcado'] == 1
                              ? Colors.green
                              : Colors.grey,
                        ),
                        onPressed: () async {
                          // ALTERNA EL ESTADO MARCADO DEL PRODUCTO
                          final nuevoEstado = producto['marcado'] == 1 ? 0 : 1;
                          // ACTUALIZAMOS EN LA BASE DE DATOS EL ATRIBUTO MARCADO DEL PRODUCTO
                          await database
                              .from('compra')
                              .update({'marcado': nuevoEstado})
                              .eq('idproducto', producto['idproducto']);
                          // RECALCULAMOS EL TOTAL
                          if (nuevoEstado == 1) {
                            precioTotalCompra += producto["precio"] * producto["cantidad"]; // SI SE MARCA, SUMAMOS EL PRECIO
                          } else {
                            precioTotalCompra -= producto["precio"] * producto["cantidad"]; // SI SE DESMARCA, RESTAMOS EL PRECIO
                          }
                          setState(() {
                            // ACTUALIZAMOS EL ESTADO DEL PRODUCTO EN LA INTERFAZ
                            producto['marcado'] = nuevoEstado;
                          });
                        },
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(producto['nombre']),
                          Text('\$${(producto['precio']).toStringAsFixed(2)}', style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                              fontSize: 12
                          )
                          )
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min, // HACEMOS QUE OCUPE LO NECESARIO
                        children: [
                          SizedBox( // SizedBox PARA TAMAÑO PERSONALIZADO DEL BOTON -
                            width: 25,
                            height: 25,
                            child: IconButton(
                                icon: const Icon(Icons.remove),
                                iconSize: 25.0,
                                onPressed: () {
                                  setState(() {
                                    if (producto['cantidad'] > 1) {
                                      producto['cantidad']--; // RESTAMOS UNO DE LA CANTIDAD
                                      // SI EL PRODUCTO ESTA MARCADO Y ES MAYOR A 1
                                      if (producto['marcado'] == 1) {
                                        setState(() {
                                          precioTotalCompra -= producto["precio"]; // ACTUALIZAMOS EL PRECIO TOTAL
                                        });
                                        restar1Cantidad(producto["idproducto"]);
                                      }
                                    }
                                });
                            },
                              padding: EdgeInsets.zero, // QUITAMOS EL ESPACIO EXTRA (PARA QUE NO SALGA EN NARNIA)
                            ),
                          ),
                          // TEXTO PARA VISUALIZAR LA CANTIDAD COMPRADA
                          Text(producto["cantidad"].toString(), style: TextStyle(fontSize: 16)),
                          SizedBox( // SizedBox PARA TAMAÑO PERSONALIZADO DEL BOTON +
                            width: 25,
                            height: 25,
                            child: IconButton(
                              icon: const Icon(Icons.add),
                              iconSize: 25.0,
                              onPressed: () {
                                setState(() {
                                  producto['cantidad']++;
                                  // SI EL PRODUCTO ESTA MARCADO, LO SUMAMOS
                                  if (producto['marcado'] == 1) {
                                    setState(() {
                                      precioTotalCompra += producto["precio"]; // SUMAR SI EL PRECIO ESTA MARCADO
                                    });
                                    sumar1Cantidad(producto["idproducto"]);
                                  }
                                });
                              },
                              padding: EdgeInsets.zero, // QUITAMOS EL ESPACIO EXTRA (PARA QUE NO SALGA EN NARNIA)
                            ),
                          ),
                          const SizedBox(width: 8), // SEPARADOR
                          Text( // FORMATEAMOS EL PRECIO A STRING PARA VISUALIZARLO BIEN
                            '\$${(producto['precio'] * producto["cantidad"]).toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16
                            ),
                          ),

                          IconButton( // ICONO PARA BORRAR EL PRODUCTO DE LA LISTA DE LA COMPRA
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              dialogoEliminacion(context, producto["idproducto"], producto["precio"], producto["cantidad"]);
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
            color: context.watch<ThemeProvider>().isDarkMode
                ? const Color(0xFF424242) // Fondo más oscuro en modo oscuro
                : const Color(0xFFE8F5E9), // Fondo claro en modo claro
            padding: const EdgeInsets.all(16),
            child: Row(
              // USAMOS spaceBetween PARA QUE SALGA UN Text AL PRINCIPIO Y OTRO AL FINAL
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  (AppLocalizations.of(context)!.totalMarked),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text( // FORMATEAMOS EL PRECIO PARA VISUALIZARLO BIEN
                  '\$${(precioTotalCompra).toStringAsFixed(2)}',
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