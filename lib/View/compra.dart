import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../Providers/themeProvider.dart';


class Compra extends StatefulWidget {
  final Database database;

  const Compra({super.key, required this.database});

  @override
  State<Compra> createState() => CompraState();
}

class CompraState extends State<Compra> {
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
    // CONSULTA SQL QUE OBTIENE LOS PRODUCTOS DE LA COMPRA,
    // JUNTO CON EL SUPERMERCADO DE CADA PRODUCTO
    final productosInmutables = await widget.database.rawQuery('''
    SELECT compra.*, productos.supermercado 
    FROM compra 
    INNER JOIN productos ON compra.idProducto = productos.id
  ''');

    // TRANSFORMAMOS LA LISTA INMUTABLE QUE DEVUELVE EL rawQuery A MUTABLE PARA ACTUALIZAR LA CANTIDAD MAS FACILMENTE.
    productosMutables = productosInmutables.map((producto) {
      return Map<String, dynamic>.from(producto);
    }).toList();

    // AGRUPAMOS LOS PRODUCTOS POR SUPERMERCADO
    final Map<String, List<Map<String, dynamic>>> agrupados = {};

    // ITERAMOS SOBRE CADA PRODUCTO OBTENIDO DE LA CONSULTA
    for (var producto in productosMutables) {
      // OBTENEMOS EL NOMBRE DEL SUPERMERCADO; SI ES NULO, USAMOS 'Sin supermercado'
      final supermercado = (producto['supermercado'] ?? 'Sin supermercado').toString();


      // ACTUALIZAMOS EL VALOR DE precioTotalCompra SOLO PARA LOS PRODUCTOS MARCADOS
      if (producto['marcado'] == 1) {
        precioTotalCompra += producto["precio"] * producto["cantidad"];
      }

      // SI EL SUPERMERCADO NO EXISTE COMO CLAVE EN EL MAPA, LO AÑADIMOS AL MAPA COMO UNA LISTA VACÍA
      if (!agrupados.containsKey(supermercado)) {
        agrupados[supermercado] = [];
      }
      // AGREGAMOS EL PRODUCTO A LA LISTA CORRESPONDIENTE DENTRO DEL MAPA
      agrupados[supermercado]?.add(producto);
    }

    // ACTUALIZAMOS EL ESTADO CON LOS PRODUCTOS AGRUPADOS PARA REFLEJARLO EN LA INTERFAZ
    setState(() {
      productosCompra = agrupados.entries.map((entry) {
        return {
          'supermercado': entry.key, // NOMBRE DEL SUPERMERCADO
          'productos': entry.value, // LISTA DE PRODUCTOS DE ESE SUPERMERCADO
        };
      }).toList();
    });

    //calcularTotalMarcados(); // ACTUALIZA EL TOTAL DE LOS PRODUCTOS MARCADOS
  }

  // /*TODO-----------------METODO CALCULAR TOTAL MARCADO (NO USADO)-----------------*/
  // Future<void> calcularTotalMarcados() async {
  //   // CONSULTA PARA OBTENER LA SUMA DE LOS PRECIOS DE LOS PRODUCTOS MARCADOS
  //   final resultado = await widget.database.rawQuery(
  //     'SELECT SUM(precio) as total FROM compra WHERE marcado = 1',
  //   );
  //   setState(() {
  //     // SI NO HAY RESULTADOS EN LA CONSULTA, EL RESULTADO SERA 0.0
  //     precioTotalCompra = (resultado.isNotEmpty && resultado[0]['total'] != null)
  //         ? (resultado[0]['total'] as num).toDouble()
  //         : 0.0;
  //   });
  // }
  /// Aumenta la cantidad de un producto en la compra en 1
  ///
  /// - Realiza una consulta SQL para incrementar la cantidad de un producto específico
  ///   identificado por 'idProducto' en la base de datos.
  Future<void> sumar1Cantidad(int idProducto) async {
    await widget.database.rawUpdate('''
    UPDATE compra set cantidad = cantidad + 1 WHERE idProducto = ?
    ''', [idProducto]);
  }
  /// Disminuye la cantidad de un producto en la compra en 1
  ///
  /// - Realiza una consulta SQL para disminuir la cantidad de un producto específico
  ///   identificado por 'idProducto' en la base de datos.
  Future<void> restar1Cantidad(int idProducto) async {
    await widget.database.rawUpdate('''
    UPDATE compra set cantidad = cantidad - 1 WHERE idProducto = ?
    ''', [idProducto]);
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
    // CONSULTA PARA OBTENER TODOS LOS PRODUCTOS MARCADOS
    final productosMarcados = await widget.database.rawQuery(
      'SELECT * FROM compra WHERE marcado = 1',
    );
    // SI NO HAY RESULTADOS EN LA CONSULTA MOSTRAMOS UN MENSAJE DE ERROR
    if (productosMarcados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos marcados para generar una factura.')),
      );
      return;
    }

    // CALCULAMOS EL PRECIO TOTAL DE LOS PRODUCTOS MARCADOS
    double precioTotal = productosMarcados.fold(0.0, (sum, producto) {
      return sum + (producto['precio'] as num).toDouble();
    });

    // OBTENEMOS SOLO LA FECHA DEL DateTime.now
    // ([0] INDICA EL PRIMER INDICE DE LA LISTA QUE SE GENERA AL USAR SPLIT)
    final fechaString = DateTime.now().toIso8601String().split('T')[0];

    // PARSEAMOS A UN FORMATO CON SENTIDO PARA EL 90% DE LA POBLACION
    final fechaActual = DateFormat("dd/MM/yyyy").format(DateTime.parse(fechaString));

    // INSERTAMOS LA NUEVA FACTURA
    final idFactura = await widget.database.insert('facturas', {
      'precio': precioTotal,
      'fecha': fechaActual, // INSERTAMOS LA FECHA SIMPLIFICADA
      'supermercado': 'Supermercado Desconocido',
    });

    // ITERAMOS SOBRE CADA PRODUCTO MARCADO PARA INSERTARLO EN LA TABLA producto_factura
    for (var producto in productosMarcados) {
      await widget.database.insert(
          'producto_factura', { // NOMBRE DE LA TABLA DONDE INSERTAMOS
        'idProducto': producto['idProducto'], //idProducto no cambia
        'idFactura': idFactura, // LO ASOCIAMOS CON EL idFactura
        'cantidad': producto["cantidad"], // LE ASIGNAMOS LA CANTIDAD COMPRADA
        'precioUnidad': producto['precio'],
        'total': precioTotal
      });
    }

    // MOSTRAMOS MENSAJE DE CONFIRMACION
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text(AppLocalizations.of(context)!.snackBarAddedReceipt)),
    );
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
  Future<void> deleteProducto(int idProducto) async{
    await widget.database.rawDelete(
      'DELETE FROM compra WHERE idProducto = ?', [idProducto],
    );
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
              (supermercado) => supermercado['productos'].any((p) => p['idProducto'] == idProducto)
      );

      // BORRAMOS EL PRODUCTO DE ESE SUPERMERCADO
      supermercado['productos'].removeWhere((p) => p['idProducto'] == idProducto);

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
      body: Column(
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
                      visualDensity: VisualDensity(horizontal: -4), // HACE QUE HAYA MENOS ESPACIO ENTRE EL LEADING Y EL TITLE
                      contentPadding: EdgeInsets.symmetric(horizontal: 4), // REDUCE EL PADDING LATERAL
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
                          await widget.database.rawUpdate(
                            'UPDATE compra SET marcado = ? WHERE idProducto = ?',
                            [nuevoEstado, producto['idProducto']],
                          );
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
                          Text('\$${(producto['precio']).toStringAsFixed(2)}', style: TextStyle(
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
                            width: 15,
                            height: 15,
                            child: IconButton(
                                icon: Icon(Icons.remove),
                                iconSize: 15.0,
                                onPressed: () {
                                  setState(() {
                                    if (producto['cantidad'] > 1) {
                                      producto['cantidad']--; // RESTAMOS UNO DE LA CANTIDAD
                                      // SI EL PRODUCTO ESTA MARCADO Y ES MAYOR A 1
                                      if (producto['marcado'] == 1) {
                                        setState(() {
                                          precioTotalCompra -= producto["precio"]; // ACTUALIZAMOS EL PRECIO TOTAL
                                        });
                                        restar1Cantidad(producto["idProducto"]);
                                      }
                                    }
                                });
                            },
                              padding: EdgeInsets.zero, // QUITAMOS EL ESPACIO EXTRA (PARA QUE NO SALGA EN NARNIA)
                            ),
                          ),
                          // TEXTO PARA VISUALIZAR LA CANTIDAD COMPRADA
                          Text(producto["cantidad"].toString(), style: TextStyle(fontSize: 14)),
                          SizedBox( // SizedBox PARA TAMAÑO PERSONALIZADO DEL BOTON +
                            width: 15,
                            height: 15,
                            child: IconButton(
                              icon: Icon(Icons.add),
                              iconSize: 15.0,
                              onPressed: () {
                                setState(() {
                                  producto['cantidad']++;
                                  // SI EL PRODUCTO ESTA MARCADO, LO SUMAMOS
                                  if (producto['marcado'] == 1) {
                                    setState(() {
                                      precioTotalCompra += producto["precio"]; // SUMAR SI EL PRECIO ESTA MARCADO
                                    });
                                    sumar1Cantidad(producto["idProducto"]);
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
                              fontSize: 13
                            ),
                          ),

                          IconButton( // ICONO PARA BORRAR EL PRODUCTO DE LA LISTA DE LA COMPRA
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              dialogoEliminacion(context, producto["idProducto"], producto["precio"], producto["cantidad"]);
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
                ? Color(0xFF424242) // Fondo más oscuro en modo oscuro
                : Color(0xFFE8F5E9), // Fondo claro en modo claro
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