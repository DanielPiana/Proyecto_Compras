import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Providers/shopping_list_provider.dart';
import '../Providers/receipts_provider.dart';
import '../Providers/theme_provider.dart';
import '../Providers/user_provider.dart';
import '../Widgets/shopping_list_placeholder.dart';
import '../Widgets/awesome_snackbar.dart';
import '../l10n/app_localizations.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;
import 'package:share_plus/share_plus.dart';

class ShoppingListView extends StatefulWidget {
  const ShoppingListView({super.key});

  @override
  State<ShoppingListView> createState() => ShoppingListViewState();
}

class ShoppingListViewState extends State<ShoppingListView> {
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
  ///   [deleteProduct] del [ShoppingListProvider].
  /// - Se muestra un snackbar de éxito si la eliminación es correcta.
  /// - Si ocurre un error durante la operación, se captura la excepción y
  ///   se muestra un snackbar de error.
  void showDeleteDialog(BuildContext context, int productId) {
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
                final shoppingProvider = context.read<ShoppingListProvider>();

                final allPurchases = List.of(
                  shoppingProvider.groupedShopping.values.expand(
                    (supermarketPurchases) => supermarketPurchases,
                  ),
                );

                final isLastItem = allPurchases.length == 1;

                Navigator.of(dialogContext).pop();

                try {
                  if (isLastItem) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message: AppLocalizations.of(context)!.product_deleted_ok,
                      contentType: asc.ContentType.success,
                    );
                  }
                  await shoppingProvider.deleteProduct(productId);

                  if (!isLastItem && context.mounted) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message: AppLocalizations.of(context)!.product_deleted_ok,
                      contentType: asc.ContentType.success,
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.error,
                      message:
                          AppLocalizations.of(context)!.receipt_deleted_error,
                      contentType: asc.ContentType.failure,
                    );
                  }
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
  /// - Si el [message] está vacío, muestra un aviso y termina.
  /// - En Windows/Linux/macOS: copia el [message] al portapapeles y muestra un snackbar de éxito.
  /// - En Android/iOS: intenta abrir WhatsApp con `https://wa.me/?text=...`.
  ///   - Si no se puede abrir, usa el diálogo de compartir genérico (`Share.share`).
  /// - Si ocurre cualquier excepción, muestra un snackbar de error.
  Future<void> shareList(BuildContext context, String message) async {
    if (message.trim().isEmpty) {
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
        await Clipboard.setData(ClipboardData(text: message));
        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.success,
          message: AppLocalizations.of(context)!.copied_list,
          contentType: asc.ContentType.success,
        );
      } else if (Platform.isAndroid || Platform.isIOS) {
        final encodedMessage = Uri.encodeComponent(message);
        final whatsappUrl = Uri.parse('https://wa.me/?text=$encodedMessage');

        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        } else {
          Share.share(message);
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
    final shoppingProvider = context.watch<ShoppingListProvider>();
    final groupedShopping = shoppingProvider.groupedShopping;

    double totalShoppingPrice = context.read<ShoppingListProvider>().totalShoppingPrice;

    return Scaffold(
      // ---------- APP BAR ----------
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.shoppingList,
          style: const TextStyle(
              fontSize: 30,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,

        // ---------- ACCIONES ( Compartir / Generar factura ----------
        actions: [
          // Generar factura
          IconButton(
            icon: const Icon(Icons.receipt),
            tooltip: AppLocalizations.of(context)!.generateReceipt,
            onPressed: () async {
              final shoppingProvider = context.read<ShoppingListProvider>();
              final markedProducts = shoppingProvider.groupedShopping.values
                  .expand((list) => list)
                  .where((p) => p.marked == 1)
                  .toList();

              // VALIDACIÓN
              if (markedProducts.isEmpty) {
                showAwesomeSnackBar(
                  context,
                  title: AppLocalizations.of(context)!.error,
                  message: AppLocalizations.of(context)!.snackBarReceiptQuantityError,
                  contentType: asc.ContentType.failure,
                );
                return;
              }

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                await context.read<ReceiptProvider>().generateReceipt(
                  markedProducts,
                  context.read<UserProvider>().uuid!,
                );

                await context.read<ShoppingListProvider>().deleteMarkedProducts();

                Navigator.pop(context);

                showAwesomeSnackBar(
                  context,
                  title: AppLocalizations.of(context)!.success,
                  message: AppLocalizations.of(context)!.receipt_created_ok,
                  contentType: asc.ContentType.success,
                );

              } catch (e) {
                Navigator.pop(context);

                showAwesomeSnackBar(
                  context,
                  title: AppLocalizations.of(context)!.error,
                  message: AppLocalizations.of(context)!.receipt_created_error,
                  contentType: asc.ContentType.failure,
                );
              }
            },
          ),

          // Compartir
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final message = context
                  .read<ShoppingListProvider>()
                  .generateShoppingListMessage(
                      context, Localizations.localeOf(context));
              await shareList(context, message);
            },
          ),
        ],
      ),

      // ---------- BODY ----------
      body: shoppingProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : shoppingProvider.groupedShoppingToShow.isEmpty
              ? const ShoppingListPlaceholder()
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: context
                            .watch<ShoppingListProvider>()
                            .groupedShoppingToShow
                            .entries
                            .length,
                        itemBuilder: (context, index) {
                          final entry = context
                              .watch<ShoppingListProvider>()
                              .groupedShoppingToShow
                              .entries
                              .toList()[index];
                          // OBTENEMOS EL SUPERMERCADO DE ESE ELEMENTO
                          final supermarket = entry.key;
                          // OBTENEMOS LA LISTA DE PRODUCTOS DE ESE SUPERMERCADO
                          final products = entry.value;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 4),
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade600, width: 0.8),
                                borderRadius: BorderRadius.circular(10),
                                color: Theme.of(context).colorScheme.surface),

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
                                  maxLines: 1,
                                  supermarket,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              children: products.map((product) {
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
                                            visualDensity: const VisualDensity(
                                                horizontal: -4),
                                            // REDUCE EL PADDING LATERAL
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 4),
                                            // BOTON PARA MARCAR Y DESMARCAR PRODUCTO
                                            leading: IconButton(
                                              // ---------- CHECKBOX DE MARCADO ----------
                                              // SI producto['marcado'] ES 1, PONEMOS UN ESTILO Y SI NO, OTRO
                                              icon: Icon(
                                                product.marked == 1
                                                    ? Icons.check_box
                                                    : Icons
                                                        .check_box_outline_blank,
                                                color: product.marked == 1
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Colors.grey,
                                              ),
                                              onPressed: () async {
                                                // ALTERNA EL ESTADO MARCADO DEL PRODUCTO
                                                final newState =
                                                    product.marked == 1
                                                        ? 0
                                                        : 1;
                                                // ACTUALIZAMOS EN LA BASE DE DATOS EL ATRIBUTO MARCADO DEL PRODUCTO
                                                await database
                                                    .from('compra')
                                                    .update({
                                                  'marcado': newState
                                                }).eq('idproducto',
                                                        product.productId);
                                                // RECALCULAMOS EL TOTAL
                                                context
                                                    .read<ShoppingListProvider>()
                                                    .toggleMarked(product);
                                              },
                                            ),

                                            // ---------- NOMBRE Y PRECIO DEL PRODUCTO ----------
                                            title: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    maxLines: 2,
                                                    product.name),
                                                Text(
                                                    '\$${(product.price).toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12))
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
                                                    icon: const Icon(
                                                        Icons.remove),
                                                    iconSize: 25.0,
                                                    onPressed: () {
                                                      setState(() {
                                                        if (product.quantity >
                                                            1) {
                                                          // SI EL PRODUCTO ESTA MARCADO Y ES MAYOR A 1
                                                          setState(() {
                                                            totalShoppingPrice -=
                                                                product
                                                                    .price; // ACTUALIZAMOS EL PRECIO TOTAL
                                                          });
                                                          context
                                                              .read<
                                                                  ShoppingListProvider>()
                                                              .decrementQuantity(
                                                                  product
                                                                      .productId);
                                                        }
                                                      });
                                                    },
                                                    padding: EdgeInsets
                                                        .zero, // QUITAMOS EL ESPACIO EXTRA (PARA QUE NO SALGA EN NARNIA)
                                                  ),
                                                ),
                                                const SizedBox(width: 2),

                                                // Cantidad del producto
                                                Text(
                                                    product.quantity
                                                        .toString(),
                                                    style: const TextStyle(
                                                        fontSize: 16)),
                                                const SizedBox(width: 2),

                                                // Iconon +
                                                SizedBox(
                                                  // SizedBox PARA TAMAÑO PERSONALIZADO DEL BOTON +
                                                  width: 25,
                                                  height: 25,
                                                  child: IconButton(
                                                    icon: const Icon(Icons.add),
                                                    iconSize: 25.0,
                                                    onPressed: () {
                                                      setState(() {
                                                        setState(() {
                                                          // SUMAR SI EL PRECIO ESTA MARCADO
                                                          totalShoppingPrice +=
                                                              product.price;
                                                        });
                                                        context
                                                            .read<
                                                                ShoppingListProvider>()
                                                            .incrementQuantity(
                                                                product
                                                                    .productId);
                                                      });
                                                    },
                                                    // QUITAMOS EL ESPACIO EXTRA (PARA QUE NO SALGA EN NARNIA)
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '\$${(product.price * product.quantity).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                ),

                                                // ---------- ICONO DE BORRAR PRODUCTO ----------
                                                IconButton(
                                                  icon:
                                                      const Icon(Icons.delete),
                                                  constraints:
                                                      const BoxConstraints(
                                                    minWidth: 35,
                                                    minHeight: 35,
                                                  ),
                                                  iconSize: 22,
                                                  color: Colors.red.shade400,
                                                  onPressed: () async {
                                                    showDeleteDialog(context,
                                                        product.productId);
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
                                      indent: 8,
                                      endIndent: 8,
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
                      padding: const EdgeInsets.all(8),
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
                          Text(
                            // FORMATEAMOS EL PRECIO PARA VISUALIZARLO BIEN
                            '\$${(totalShoppingPrice).toStringAsFixed(2)}',
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
