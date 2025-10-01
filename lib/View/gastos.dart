import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/facturaProvider.dart';
import '../Providers/userProvider.dart';
import '../Widgets/awesomeSnackbar.dart';
import '../l10n/app_localizations.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;

class Gastos extends StatefulWidget {
  const Gastos({super.key});

  @override
  State<Gastos> createState() => GastosState();
}

class GastosState extends State<Gastos> {
  SupabaseClient database = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
  }

  /*TODO-----------------DIALOGO DE ELIMINACION DE PRODUCTO EN LISTA-----------------*/

  /// Muestra un cuadro de diálogo de confirmación para la eliminación de una factura.
  ///
  /// Este método muestra un 'AlertDialog' en el que se le pregunta al usuario si está
  /// seguro de eliminar una factura específica. El cuadro de diálogo contiene dos botones:
  /// - "Cancelar": Cierra el cuadro de diálogo sin realizar ninguna acción.
  /// - "Eliminar": Elimina la factura especificada por el 'idFactura' y recarga las facturas.
  ///
  /// Además, se informa al usuario de que los productos asociados a la factura no serán eliminados.
  ///
  /// El cuadro de diálogo se muestra de forma asincrónica y se cierra automáticamente al
  /// confirmar la eliminación o al cancelar la acción.
  void dialogoEliminacion(BuildContext context, int idFactura) {
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
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                AppLocalizations.of(context)!.cancel,
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await context.read<FacturaProvider>().borrarFactura(
                    idFactura,
                    context.read<UserProvider>().uuid!,
                  );
                  showAwesomeSnackBar(
                    context,
                    title: AppLocalizations.of(context)!.success,
                    message: AppLocalizations.of(context)!.receipt_deleted_ok,
                    contentType: asc.ContentType.success,
                  );
                } catch (e) {
                  showAwesomeSnackBar(
                    context,
                    title: 'Error',
                    message:
                    AppLocalizations.of(context)!.receipt_deleted_error,
                    contentType: asc.ContentType.failure,
                  );
                }
              },
              child: Text(
                AppLocalizations.of(context)!.delete,
                style: const TextStyle(color: Colors.red),
              ),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final facturas = context.watch<FacturaProvider>().facturas;
    return Scaffold(
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
      body: facturas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: facturas.length,
        itemBuilder: (context, index) {
          final factura = facturas[index];
          final double precioTotal = factura.productos.fold(
            0.0,
                (sum, p) => sum + (p.precioUnidad * p.cantidad),
          );
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade600, width: 0.8),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white),
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
                      factura.fecha,
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
                        dialogoEliminacion(context, factura.id!);
                      },
                      icon: const Icon(Icons.delete),
                      iconSize: 22,
                      color: Colors.red.shade400,
                    ),
                  ],
                ),
              ),
              children: [
                ...factura.productos.map((producto) {
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
                              title: Text(producto.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${AppLocalizations.of(context)!.quantity}${producto.cantidad}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Text(
                                '\$${producto.precioUnidad.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
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
                        indent: 16,
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
                    '\$${precioTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
