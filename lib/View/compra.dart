import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/compraProvider.dart';
import '../Providers/facturaProvider.dart';
import '../Providers/themeProvider.dart';
import '../Providers/userProvider.dart';
import '../Widgets/awesomeSnackbar.dart';
import '../l10n/app_localizations.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;


class Compra extends StatefulWidget {

  const Compra({super.key});

  @override
  State<Compra> createState() => CompraState();
}

class CompraState extends State<Compra> {

  SupabaseClient database = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
  }

  /*TODO-----------------DIALOGO DE ELIMINACION DE PRODUCTO EN LISTA-----------------*/
  /// Muestra un cuadro de diálogo de confirmacion antes de eliminar un producto de la lista de la compra
  ///
  /// Si el usuario confirma la eliminación, llama al método 'deleteProducto(idProducto)' y luego
  /// actualizarPrecio(idProducto,precio,cantidad) para actualizar el precio de los productos marcados
  ///
  /// Maneja excepciones para evitar fallos durante la operación con la base de datos.
  void dialogoEliminacion(BuildContext context, int idProducto) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text( // TITULO DE LA ALERTA
            AppLocalizations.of(context)!.titleConfirmDialog,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            AppLocalizations.of(context)!.deleteConfirmationSP,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                AppLocalizations.of(context)!.cancel,
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                Future.delayed(Duration.zero, () {
                  showAwesomeSnackBar(
                    context,
                    title: AppLocalizations.of(context)!.success,
                    message: AppLocalizations.of(context)!.receipt_deleted_ok,
                    contentType: asc.ContentType.success,
                  );
                });
              },
              child: Text(AppLocalizations.of(context)!.delete,
                  style: const TextStyle(color: Colors.red)),
            )
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {

    final compraProvider = context.watch<CompraProvider>();
    final comprasAgrupadas = compraProvider.comprasAgrupadas;

    double precioTotalCompra = context.read<CompraProvider>().precioTotalCompra;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.shoppingList,
          style: const TextStyle(
              fontSize: 30,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt),
            tooltip: AppLocalizations.of(context)!.generateReceipt,
            onPressed: () async {
              final compraProvider = context.read<CompraProvider>();
              final productosMarcados = compraProvider.comprasAgrupadas.values
                  .expand((lista) => lista)
                  .where((p) => p.marcado == 1)
                  .toList();

              if (productosMarcados.isEmpty) {
                showAwesomeSnackBar(
                  context,
                  title: 'Error',
                  message: AppLocalizations.of(context)!.snackBarReceiptQuantityError,
                  contentType: asc.ContentType.failure,
                );
                return;
              }

              try {
                await context.read<FacturaProvider>().generarFactura(
                  productosMarcados,
                  context.read<UserProvider>().uuid!,
                );

                showAwesomeSnackBar(
                  context,
                  title: AppLocalizations.of(context)!.success,
                  message: AppLocalizations.of(context)!.receipt_created_ok,
                  contentType: asc.ContentType.success,
                );
              } catch (e) {
                showAwesomeSnackBar(
                  context,
                  title: 'Error',
                  message: AppLocalizations.of(context)!.receipt_created_error,
                  contentType: asc.ContentType.failure,
                );
              }
            },
          )
        ],
      ),
      body: comprasAgrupadas.isEmpty ? const Center(
        child: CircularProgressIndicator(),
      ) :
      Column(
        children: [
          Expanded( // EXPANDED PARA QUE EL ListView.Builder NO DE ERROR
            child: ListView.builder(
              // TAMAÑO EN BASE A LA CANTIDAD DE SUPERMERCADOS QUE HAY
              itemCount: context.watch<CompraProvider>().comprasAgrupadas.entries.length,
              itemBuilder: (context, index) {
                // OBTENEMOS UN ELEMENTO DE LA LISTA BASANDONOS EN EL INDICE
                final entry = context.watch<CompraProvider>().comprasAgrupadas.entries.toList()[index];
                // OBTENEMOS EL SUPERMERCADO DE ESE ELEMENTO
                final supermercado = entry.key;
                // OBTENEMOS LA LISTA DE PRODUCTOS DE ESE SUPERMERCADO
                final productos = entry.value;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade600, width: 0.8),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    key: Key(index.toString()),
                    title: Container(
                      constraints: const BoxConstraints(
                        minHeight: 51,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        supermercado,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    children: productos.map((producto) {
                      return Column(
                        children: [
                          SizedBox(
                            height: 75,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: Center(
                                child: ListTile(
                                  visualDensity: const VisualDensity(horizontal: -4), // HACE QUE HAYA MENOS ESPACIO ENTRE EL LEADING Y EL TITLE
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4), // REDUCE EL PADDING LATERAL
                                  leading: IconButton( // BOTON PARA MARCAR Y DESMARCAR PRODUCTO
                                    icon: Icon( // SI producto['marcado'] ES 1, PONEMOS UN ESTILO Y SI NO, OTRO
                                      producto.marcado == 1
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank,
                                      color: producto.marcado == 1
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.grey,
                                    ),
                                    onPressed: () async {
                                      // ALTERNA EL ESTADO MARCADO DEL PRODUCTO
                                      final nuevoEstado = producto.marcado == 1 ? 0 : 1;
                                      // ACTUALIZAMOS EN LA BASE DE DATOS EL ATRIBUTO MARCADO DEL PRODUCTO
                                      await database
                                          .from('compra')
                                          .update({'marcado': nuevoEstado})
                                          .eq('idproducto', producto.idProducto);
                                      // RECALCULAMOS EL TOTAL
                                      context.read<CompraProvider>().alternarMarcado(producto);
                                    },
                                  ),
                                  title: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(producto.nombre),
                                      Text('\$${(producto.precio).toStringAsFixed(2)}', style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
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
                                              if (producto.cantidad > 1) {
                                                // SI EL PRODUCTO ESTA MARCADO Y ES MAYOR A 1
                                                setState(() {
                                                  precioTotalCompra -= producto.precio; // ACTUALIZAMOS EL PRECIO TOTAL
                                                });
                                                context.read<CompraProvider>().restar1Cantidad(producto.idProducto);
                                              }
                                            });
                                          },
                                          padding: EdgeInsets.zero, // QUITAMOS EL ESPACIO EXTRA (PARA QUE NO SALGA EN NARNIA)
                                        ),
                                      ),
                                      // TEXTO PARA VISUALIZAR LA CANTIDAD COMPRADA
                                      const SizedBox(width: 2),
                                      Text(producto.cantidad.toString(), style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 2),
                                      SizedBox( // SizedBox PARA TAMAÑO PERSONALIZADO DEL BOTON +
                                        width: 25,
                                        height: 25,
                                        child: IconButton(
                                          icon: const Icon(Icons.add),
                                          iconSize: 25.0,
                                          onPressed: () {
                                            setState(() {
                                              // SI EL PRODUCTO ESTA MARCADO, LO SUMAMOS
                                              setState(() {
                                                precioTotalCompra += producto.precio; // SUMAR SI EL PRECIO ESTA MARCADO
                                              });
                                              context.read<CompraProvider>().sumar1Cantidad(producto.idProducto);
                                            });
                                          },
                                          padding: EdgeInsets.zero, // QUITAMOS EL ESPACIO EXTRA (PARA QUE NO SALGA EN NARNIA)
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text( // FORMATEAMOS EL PRECIO A STRING PARA VISUALIZARLO BIEN
                                        '\$${(producto.precio * producto.cantidad).toStringAsFixed(2)}',
                                        style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16
                                        ),
                                      ),
                                      IconButton( // ICONO PARA BORRAR EL PRODUCTO DE LA LISTA DE LA COMPRA
                                        icon: const Icon(Icons.delete),
                                        constraints: const BoxConstraints(
                                          minWidth: 35,
                                          minHeight: 35,
                                        ),
                                        iconSize: 22,
                                        color: Colors.red.shade400,
                                        onPressed: () async {
                                          dialogoEliminacion(context, producto.idProducto);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.8,
                            indent: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          Container(
            color: context.watch<ThemeProvider>().isDarkMode
                ? const Color(0xFF424242)
                : const Color(0xFFE8F5E9),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
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