import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Providers/compraProvider.dart';
import '../Providers/facturaProvider.dart';
import '../Providers/themeProvider.dart';
import '../Providers/userProvider.dart';
import '../Widgets/PlaceHolderCompra.dart';
import '../Widgets/awesomeSnackbar.dart';
import '../l10n/app_localizations.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;
import 'package:share_plus/share_plus.dart';


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
  /// Muestra un cuadro de diálogo de confirmación para eliminar un producto de la lista de la compra.
  ///
  /// Flujo principal:
  /// - Muestra un cuadro de diálogo pidiendo al usuario confirmar la eliminación.
  /// - Si el usuario cancela, se cierra el cuadro de diálogo sin cambios.
  /// - Si confirma, se cierra el cuadro de diálogo y se llama al método
  ///   [deleteProducto] del [CompraProvider].
  /// - Se muestra un snackbar de éxito si la eliminación es correcta.
  /// - Si ocurre un error durante la operación, se captura la excepción y
  ///   se muestra un snackbar de error.
  void dialogoEliminacion(BuildContext context, int idProducto) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(

          // ---------- TÍTULO ----------
          title: Text(
            AppLocalizations.of(context)!.titleConfirmDialog,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          // ---------- CONTENIDO ----------
          content: Text(
            AppLocalizations.of(context)!.deleteConfirmationSP,
            style: const TextStyle(fontSize: 16),
          ),

          // ---------- ACCIONES (Cancelar / Eliminar) ----------
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

                final provider = context.read<CompraProvider>();
                try {
                  await provider.deleteProducto(idProducto);
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message: AppLocalizations.of(context)!.receipt_deleted_ok,
                      contentType: asc.ContentType.success,
                    );
                } catch (e) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.error,
                      message: AppLocalizations.of(context)!.receipt_deleted_error,
                      contentType: asc.ContentType.failure,
                    );
                }
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


  /// Comparte la lista de la compra adaptándose a la plataforma (escritorio vs. móvil).
  ///
  /// Flujo principal:
  /// - Si el [mensaje] está vacío, muestra un aviso y termina.
  /// - En Windows/Linux/macOS: copia el [mensaje] al portapapeles y muestra un snackbar de éxito.
  /// - En Android/iOS: intenta abrir WhatsApp con `https://wa.me/?text=...`.
  ///   - Si no se puede abrir, usa el diálogo de compartir genérico (`Share.share`).
  /// - Si ocurre cualquier excepción, muestra un snackbar de error.
  Future<void> compartirLista(BuildContext context, String mensaje) async {
    if (mensaje.trim().isEmpty) {
      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.warning,
        message: AppLocalizations.of(context)!.share_empty_list,
        contentType: asc.ContentType.warning,
      );
      return;
    }

    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await Clipboard.setData(ClipboardData(text: mensaje));
        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.success,
          message: AppLocalizations.of(context)!.copied_list,
          contentType: asc.ContentType.success,
        );
      } else if (Platform.isAndroid || Platform.isIOS) {
        final encodedMessage = Uri.encodeComponent(mensaje);
        final whatsappUrl = Uri.parse('https://wa.me/?text=$encodedMessage');

        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        } else {
          Share.share(mensaje);
        }
      }
    } catch (e) {
      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.error,
        message: AppLocalizations.of(context)!.share_shopping_list_error,
        contentType: asc.ContentType.failure,
      );
    }
  }


  @override
  Widget build(BuildContext context) {

    final compraProvider = context.watch<CompraProvider>();
    final comprasAgrupadas = compraProvider.comprasAgrupadas;

    double precioTotalCompra = context.read<CompraProvider>().precioTotalCompra;

    return Scaffold(

      // ---------- APP BAR ----------
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

        // ---------- ACCIONES ( Compartir / Generar factura ----------
        actions: [
          // Generar factura
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

                context.read<CompraProvider>().resetearProductosListaCompra();

              } catch (e) {
                showAwesomeSnackBar(
                  context,
                  title: 'Error',
                  message: AppLocalizations.of(context)!.receipt_created_error,
                  contentType: asc.ContentType.failure,
                );
              }
            },
          ),

          // Compartir
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir lista',
            onPressed: () async {
              final mensaje = context.read<CompraProvider>().generarMensajeListaCompra(context,Localizations.localeOf(context));
              await compartirLista(context, mensaje);
            },
          ),
        ],
      ),

      // ---------- BODY ----------
      body: compraProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : comprasAgrupadas.isEmpty
          ? const PlaceholderCompra()
          : Column(
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

                  // ---------- SECCIÓN DE SUPERMERCADO ----------
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

                                // ---------- LISTA DE PRODUCTOS ----------
                                child: ListTile(
                                  // HACE QUE HAYA MENOS ESPACIO ENTRE EL LEADING Y EL TITLE
                                  visualDensity: const VisualDensity(horizontal: -4),
                                  // REDUCE EL PADDING LATERAL
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                  // BOTON PARA MARCAR Y DESMARCAR PRODUCTO
                                  leading: IconButton(

                                    // ---------- CHECKBOX DE MARCADO ----------
                                    // SI producto['marcado'] ES 1, PONEMOS UN ESTILO Y SI NO, OTRO
                                    icon: Icon(
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

                                  // ---------- NOMBRE Y PRECIO DEL PRODUCTO ----------
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
                                    // HACEMOS QUE OCUPE LO NECESARIO
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // SizedBox PARA TAMAÑO PERSONALIZADO DEL BOTON
                                      // Icono -
                                      SizedBox(
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
                                      const SizedBox(width: 2),

                                      // Cantidad del producto
                                      Text(producto.cantidad.toString(), style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 2),

                                      // Iconon +
                                      SizedBox( // SizedBox PARA TAMAÑO PERSONALIZADO DEL BOTON +
                                        width: 25,
                                        height: 25,
                                        child: IconButton(
                                          icon: const Icon(Icons.add),
                                          iconSize: 25.0,
                                          onPressed: () {
                                            setState(() {
                                              setState(() {
                                                // SUMAR SI EL PRECIO ESTA MARCADO
                                                precioTotalCompra += producto.precio;
                                              });
                                              context.read<CompraProvider>().sumar1Cantidad(producto.idProducto);
                                            });
                                          },
                                          // QUITAMOS EL ESPACIO EXTRA (PARA QUE NO SALGA EN NARNIA)
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '\$${(producto.precio * producto.cantidad).toStringAsFixed(2)}',
                                        style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16
                                        ),
                                      ),

                                      // ---------- ICONO DE BORRAR PRODUCTO ----------
                                      IconButton(
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