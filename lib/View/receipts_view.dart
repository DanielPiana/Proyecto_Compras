import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/receipts_provider.dart';
import '../Providers/user_provider.dart';
import '../Widgets/receipts_placeholder.dart';
import '../Widgets/awesome_snackbar.dart';
import '../l10n/app_localizations.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;

class ReceiptsView extends StatefulWidget {
  const ReceiptsView({super.key});

  @override
  State<ReceiptsView> createState() => ReceiptsViewState();
}

class ReceiptsViewState extends State<ReceiptsView> {
  SupabaseClient database = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
  }

  /*TODO-----------------DIALOGO DE ELIMINACION DE PRODUCTO EN LISTA-----------------*/
  /// Muestra un cuadro de diálogo de confirmación para eliminar una factura.
  ///
  /// Flujo principal:
  /// - Pregunta al usuario si desea eliminar la factura.
  /// - Si confirma, lo elimina localmente y luego intenta eliminarlo en el servidor.
  /// - Si ocurre un error en el servidor, restaura la factura en local y muestra un mensaje de error.
  void showDeleteDialog(BuildContext context, int receiptId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.titleConfirmDialog,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            AppLocalizations.of(context)!.deleteConfirmationR,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            // Cancel
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),

            // Delete
            ElevatedButton(
              onPressed: () async {
                final receiptProvider = context.read<ReceiptProvider>();
                final userUuid = context.read<UserProvider>().uuid!;
                final allReceipts = List.of(receiptProvider.receipts);
                final isLastReceipt = allReceipts.length == 1;

                Navigator.of(dialogContext).pop();

                try {
                  if (isLastReceipt) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message:
                      AppLocalizations.of(context)!.receipt_deleted_ok,
                      contentType: asc.ContentType.success,
                    );
                  }

                  await receiptProvider.deleteReceipt(receiptId, userUuid);

                  if (!isLastReceipt && context.mounted) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message:
                      AppLocalizations.of(context)!.receipt_deleted_ok,
                      contentType: asc.ContentType.success,
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.error,
                      message: AppLocalizations.of(context)!
                          .receipt_deleted_error,
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

  @override
  Widget build(BuildContext context) {
    final receipts = context.watch<ReceiptProvider>().receipts;
    final receiptProvider = context.watch<ReceiptProvider>();
    return Scaffold(
      // ---------- APP BAR ----------
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.receipt,
          style: const TextStyle(
            fontSize: 30,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      // ---------- BODY ----------
      body: Builder(
          builder: (context) {
            final isLight = Theme.of(context).brightness == Brightness.light;
            return receiptProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : receiptProvider.receiptsToShow.isEmpty
                ? const ReceiptsPlaceholder()
                : ListView.builder(
              itemCount: receiptProvider.receiptsToShow.length,
              itemBuilder: (context, index) {
                final receipt = receiptProvider.receiptsToShow[index];
                  final double totalPrice = receipt.products.fold(
                    0.0,
                        (sum, p) => sum + (p.unitPrice * p.quantity),
                  );
                  return Container(
                    margin: const EdgeInsets.symmetric(
                        vertical: 4, horizontal: 4),
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.shade600, width: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        color: Theme.of(context).colorScheme.surface),

                    // ---------- SECCIÓN DE FECHA ----------
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Container(
                        constraints: const BoxConstraints(
                          minHeight: 48,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              receipt.date,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 35,
                                minHeight: 35,
                              ),
                              onPressed: () {
                                showDeleteDialog(context, receipt.id!);
                              },
                              icon: const Icon(Icons.delete),
                              iconSize: 22,
                              color: Colors.red.shade400,
                            ),
                          ],
                        ),
                      ),

                      // ---------- LISTA DE FACTURAS ----------
                      children: [
                        ...receipt.products.map((product) {
                          return Column(
                            children: [
                              SizedBox(
                                height: 75,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Center(
                                    child: ListTile(
                                      title: Text(product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${AppLocalizations.of(context)!
                                            .quantity}${product.quantity}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      trailing: Text(
                                        '\$${product.unitPrice
                                            .toStringAsFixed(2)}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Theme
                                                .of(context)
                                                .colorScheme
                                                .primary,
                                            fontSize: 15
                                        ),
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
                        }),
                        ListTile(
                          title: Text(
                            AppLocalizations.of(context)!.totalPrice,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: Text(
                            '\$${totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme
                                  .of(context)
                                  .colorScheme
                                  .primary,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
    );
  }
}
