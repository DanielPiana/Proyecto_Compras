import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/utils/capitalize.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/shopping_list_provider.dart';
import '../Providers/products_provider.dart';
import '../Providers/user_provider.dart';
import '../Widgets/scan_barcode_screen.dart';
import '../Widgets/products_placeholder.dart';
import '../Widgets/awesome_snackbar.dart';
import '../l10n/app_localizations.dart';
import '../models/product_model.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;
import 'package:flutter/services.dart';

import '../services/openfood_service.dart';
import '../utils/image_name_normalizer.dart';
import '../utils/image_picker.dart';

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => ProductsViewState();
}

class ProductsViewState extends State<ProductsView> {
  late String userId;

  SupabaseClient database = Supabase.instance.client;

  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /*TODO-----------------INITIALIZE-----------------*/
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userUuid = context.read<UserProvider>().uuid;
      // SI NO HAY USUARIO, LE MANDAMOS A LA PESTAÑA DE LOGIN
      if (userUuid != null) {
        setState(() {
          userId = userUuid;
        });
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  /*TODO-----------------DIALOGO DE ELIMINACION DE PRODUCTO-----------------*/

  /// Muestra un cuadro de diálogo de confirmación para eliminar un producto.
  ///
  /// Flujo principal:
  /// - Pregunta al usuario si desea eliminar el producto.
  /// - Si confirma, lo elimina localmente y luego intenta eliminarlo en el servidor.
  /// - Si ocurre un error en el servidor, restaura el producto en local y muestra un mensaje de error.
  ///
  /// Parámetros:
  /// - [context]: Contexto de la aplicación.
  /// - [productId]: Identificador del producto a eliminar.
  ///
  /// Retorna:
  /// - `void` (no retorna nada).
  void showDeleteDialog(BuildContext context, int productId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          // ---------- TÍTULO ----------
          title: Text(
            AppLocalizations.of(context)!.titleConfirmDialog,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),

          // ---------- CONTENIDO ----------
          content: Text(
            AppLocalizations.of(context)!.deleteConfirmationP,
            style: const TextStyle(fontSize: 14),
          ),

          // ---------- ACCIONES (Cancelar / Eliminar) ----------
          actions: [
            // Cancelar
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                AppLocalizations.of(context)!.cancel,
              ),
            ),

            // Eliminar
            ElevatedButton(
              onPressed: () async {
                final productProvider = context.read<ProductProvider>();
                final allProducts = List.of(productProvider.products);
                final isLastProduct = allProducts.length == 1;

                final backupProduct = productProvider.products
                    .firstWhere((p) => p.id == productId);

                productProvider.removeLocalProduct(productId);

                Navigator.of(dialogContext).pop();

                try {
                  if (isLastProduct) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message: AppLocalizations.of(context)!.product_deleted_ok,
                      contentType: asc.ContentType.success,
                    );
                  }

                  await productProvider.deleteProduct(context, productId);

                  if (!isLastProduct && context.mounted) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message: AppLocalizations.of(context)!.product_deleted_ok,
                      contentType: asc.ContentType.success,
                    );
                  }
                } catch (error) {
                  productProvider.addLocalProduct(backupProduct);

                  if (context.mounted) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.error,
                      message:
                          AppLocalizations.of(context)!.product_deleted_error,
                      contentType: asc.ContentType.failure,
                    );
                  }
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

  /*TODO-----------------DIALOGO DE EDICION DE PRODUCTO-----------------*/

  /// Muestra un cuadro de diálogo para editar un producto existente.
  ///
  /// Flujo principal:
  /// - Carga los valores actuales del producto en los campos de texto.
  /// - Permite modificar nombre, descripción, precio, supermercado e imagen.
  /// - Valida los campos en tiempo real mostrando iconos de estado y mensajes de error.
  /// - Si se selecciona una nueva imagen, se sube a Supabase y se obtiene la URL pública.
  /// - Al confirmar, se construye un nuevo objeto [ProductModel] actualizado.
  /// - Se actualiza el producto en la base de datos mediante el [ProductProvider].
  /// - Si la operación es exitosa, se muestra un snackbar de éxito; si falla, se muestra un snackbar de error.
  ///
  /// Parámetros:
  /// - [context]: Contexto de la aplicación.
  /// - [producto]: Instancia de [ProductModel] que se desea editar.
  ///
  /// Retorna:
  /// - `void` (no retorna nada).
  ///
  /// Excepciones:
  /// - Puede lanzar errores relacionados con la carga de imágenes o la actualización en Supabase.
  void showEditDialog(BuildContext context, ProductModel producto) async {
    final TextEditingController nameController = TextEditingController(text: producto.name);
    final TextEditingController descriptionController = TextEditingController(text: producto.description);
    final TextEditingController priceController = TextEditingController(text: producto.price.toString());
    final TextEditingController barcodeController = TextEditingController(text: producto.barCode ?? "");

    final List<String> supermarkets =
        await context.read<ProductProvider>().getSupermarkets();
    String selectedSupermarket = producto.supermarket;

    String? imageScanned = producto.photo.isNotEmpty ? producto.photo : null;
    File? imageFilePicker; // Imagen seleccionada del usuario

    bool nameValid = producto.name.trim().isNotEmpty;
    bool priceValid = true;
    bool supermarketValid = producto.supermarket.trim().isNotEmpty;

    bool nameTouched = false;
    bool priceTouched = false;
    bool supermarketTouched = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              // ---------- TÍTULO ----------
              title: Text(AppLocalizations.of(context)!.editProduct),

              // ---------- CONTENIDO ----------
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    if (isMobile)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(AppLocalizations.of(context)!.scan_barcode),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ScanBarcodeScreen()),
                          );

                          if (result != null && result is String) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                  child: CircularProgressIndicator()),
                            );

                            try {
                              final product = await OpenFoodService
                                  .getProductByBarcode(result);
                              Navigator.pop(context);

                              if (product != null) {
                                setState(() {
                                  imageScanned = product.imageFrontUrl;
                                  imageFilePicker = null;

                                  barcodeController.text = result;
                                  nameController.text = product.productName ??
                                      product.genericName ??
                                      '';
                                  descriptionController.text =
                                      product.brands ?? '';
                                });
                              } else {
                                showAwesomeSnackBar(
                                  context,
                                  title: AppLocalizations.of(context)!.warning,
                                  message: AppLocalizations.of(context)!.product_not_found,
                                  contentType: asc.ContentType.warning,
                                );
                              }
                            } catch (_) {
                              Navigator.pop(context);
                              showAwesomeSnackBar(
                                context,
                                title: AppLocalizations.of(context)!.error,
                                message: AppLocalizations.of(context)!.unexpected_error_finding_product,
                                contentType: asc.ContentType.failure,
                              );
                            }
                          }
                        },
                      ),
                    const SizedBox(height: 10),

                    // ---------- CAMPO DE CÓDIGO DE BARRAS ----------
                    if (barcodeController.text.isNotEmpty)
                      TextField(
                          decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.barcode),
                          controller: barcodeController,
                          readOnly: true),
                    const SizedBox(height: 10),
                    // ---------- CAMPO NOMBRE ----------
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.name,
                        suffixIcon: nameTouched
                            ? (nameValid
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          nameTouched = true;
                          nameValid = value.trim().isNotEmpty;
                        });
                      },
                    ),
                    if (nameTouched && !nameValid)
                      Text(AppLocalizations.of(context)!.name_error_message,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),

                    // ---------- CAMPO DESCRIPCIÓN ----------
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.description,
                        suffixIcon:
                            const Icon(Icons.check_circle, color: Colors.green),
                      ),
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 10),

                    // ---------- CAMPO DE PRECIO ----------
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.price,
                        suffixIcon: priceTouched
                            ? (priceValid
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final input = value.trim().replaceAll(',', '.');
                        setState(() {
                          priceTouched = true;
                          priceValid = double.tryParse(input) != null;
                        });
                      },
                    ),
                    if (priceTouched && !priceValid)
                      Text(AppLocalizations.of(context)!.price_error_message,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),

                    // ---------- SELECCIÓN SUPERMERCADO ----------
                    DropdownButtonFormField<String>(
                      value: selectedSupermarket,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.supermarket,
                        suffixIcon: supermarketTouched
                            ? (supermarketValid
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      items: supermarkets.map((supermarket) {
                        return DropdownMenuItem<String>(
                          value: supermarket,
                          child: SizedBox(
                            width: double.infinity,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade400, width: 0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  Text(supermarket, style: const TextStyle(fontSize: 16)),
                            ),
                          ),
                        );
                      }).toList(),
                      selectedItemBuilder: (context) {
                        return supermarkets.map((supermarket) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child:
                            Text(supermarket, style: const TextStyle(fontSize: 16)),
                          );
                        }).toList();
                      },
                      onChanged: (newSupermarket) {
                        if (newSupermarket != null) {
                          setState(() {
                            supermarketTouched = true;
                            selectedSupermarket = newSupermarket;
                            supermarketValid = newSupermarket.trim().isNotEmpty;
                          });
                        }
                      },
                    ),
                    if (supermarketTouched && !supermarketValid)
                      Text(
                          AppLocalizations.of(context)!
                              .supermarket_error_message,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // BOTÓN: Seleccionar imagen (galería en móvil, archivo en PC)
                              Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey[700]!, width: 0.8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.photo_library,
                                        color: Colors.green, size: 28),
                                    tooltip: AppLocalizations.of(context)!
                                        .select_photo,
                                    onPressed: () async {
                                      final file = await ImagePickerHelper
                                          .imageFromGallery();
                                      if (file != null) {
                                        setState(() {
                                          imageFilePicker = file;
                                          imageScanned = null;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              // BOTÓN: Cámara en móvil / pegar imagen desde portapapeles en PC
                              Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey[700]!, width: 0.8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.camera_alt,
                                        color: Colors.green, size: 28),
                                    tooltip: isMobile
                                        ? AppLocalizations.of(context)!
                                            .open_camera
                                        : AppLocalizations.of(context)!.paste_image_from_clipboard,
                                    onPressed: () async {
                                      final file = await ImagePickerHelper
                                          .imageFromClipboard();
                                      if (file != null) {
                                        setState(() {
                                          imageFilePicker = file;
                                          imageScanned = null;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // ---------- PREVIEW IMAGEN ----------
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: Builder(
                                builder: (_) {
                                  if (imageFilePicker != null) {
                                    return Image.file(imageFilePicker!,
                                        fit: BoxFit.contain);
                                  } else if (imageScanned != null &&
                                      imageScanned!.isNotEmpty) {
                                    return Image.network(imageScanned!,
                                        fit: BoxFit.contain);
                                  } else {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(Icons.image_outlined,
                                            size: 60, color: Colors.white70),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final String? barcode = barcodeController.text.isEmpty
                        ? null
                        : barcodeController.text;
                    final String newName = nameController.text.trim();
                    final String newDescription =
                        descriptionController.text.trim();
                    final String inputPrice =
                        priceController.text.trim().replaceAll(',', '.');
                    final double? newParsedPrice =
                        double.tryParse(inputPrice);

                    if (barcode != null &&
                        barcode.isNotEmpty &&
                        barcode != producto.barCode &&
                        context.read<ProductProvider>().existsWithBarCode(barcode)) {
                      showAwesomeSnackBar(
                        dialogCtx,
                        title: AppLocalizations.of(context)!.error,
                        message: AppLocalizations.of(context)!.barcode_already_registered,
                        contentType: asc.ContentType.failure,
                      );
                      return;
                    }

                    if (!nameValid ||
                        !priceValid ||
                        !supermarketValid ||
                        newParsedPrice == null) {
                      return;
                    }

                    final double newPrice = newParsedPrice;
                    String imageUrl = producto.photo;

                    if (imageFilePicker != null) {
                      final bytes = await imageFilePicker!.readAsBytes();
                      final fileName = normalizeImageName(newName);
                      final path =
                          'productos/${producto.userUuid}/$fileName.jpg';

                      await Supabase.instance.client.storage
                          .from('fotos')
                          .uploadBinary(path, bytes,
                              fileOptions:
                                  const FileOptions(contentType: 'image/jpeg'));

                      imageUrl = Supabase.instance.client.storage
                          .from('fotos')
                          .getPublicUrl(path);
                    } else if (imageScanned != null) {
                      imageUrl = imageScanned!;
                    }

                    final updatedProduct = ProductModel(
                      id: producto.id,
                      barCode: barcode,
                      name: newName,
                      description: newDescription,
                      price: newPrice,
                      supermarket: selectedSupermarket,
                      userUuid: producto.userUuid,
                      photo: imageUrl,
                    );

                    Navigator.of(dialogContext).pop();

                    try {
                      await context.read<ProductProvider>().updateProduct(
                            updatedProduct,
                            context.read<ShoppingListProvider>(),
                          );

                      showAwesomeSnackBar(
                        context,
                        title: AppLocalizations.of(context)!.success,
                        message:
                            AppLocalizations.of(context)!.product_updated_ok,
                        contentType: asc.ContentType.success,
                      );
                    } catch (e) {
                      showAwesomeSnackBar(
                        context,
                        title: AppLocalizations.of(context)!.error,
                        message:
                            AppLocalizations.of(context)!.product_updated_error,
                        contentType: asc.ContentType.failure,
                      );
                    }
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

  /*TODO-----------------DIALOGO DE CREACION DE PRODUCTO-----------------*/

  /// Muestra un cuadro de diálogo para crear un nuevo producto.
  ///
  /// Flujo principal:
  /// - Permite ingresar nombre, descripción y precio del producto.
  /// - Permite seleccionar un supermercado existente o crear uno nuevo.
  /// - Valida los campos en tiempo real, mostrando iconos de estado y mensajes de error.
  /// - Da la opción de subir una imagen y almacenarla en Supabase.
  /// - Construye un nuevo [ProductModel] con los datos ingresados.
  /// - Se guarda localmente y luego se intenta guardar en la base de datos.
  /// - Se notifica al usuario con un snackbar de éxito o de error según el resultado.
  ///
  /// Parámetros:
  /// - [context]: Contexto de la aplicación.
  ///
  /// Retorna:
  /// - `void` (no retorna nada).
  ///
  /// Excepciones:
  /// - Puede lanzar errores relacionados con la carga de imágenes o la creación en Supabase.
  void showCreateDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController priceController = TextEditingController(text: "0");
    final TextEditingController newSupermarketController = TextEditingController();
    final TextEditingController barcodeController = TextEditingController();

    String? imageScanned; // Imagen de escaneo
    File? imageFilePicker; // Imagen seleccionada del usuario
    String? selectedSupermarket;
    bool creatingSupermarket = false;

    bool nameValid = false;
    bool priceValid = true;
    bool supermarketValid = false;

    bool nameTouched = false;
    bool priceTouched = false;
    bool supermarketTouched = false;

    final productProvider = context.read<ProductProvider>();
    final supermarketsList = productProvider.productsBySupermarket.keys.toList()
      ..add(AppLocalizations.of(context)!.selectSupermarketNameDDB);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.createProduct),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    // ---------- ESCANEO DE CÓDIGO DE BARRAS ----------
                    if (isMobile)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(AppLocalizations.of(context)!.scan_barcode),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ScanBarcodeScreen()),
                          );

                          if (result != null && result is String) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                  child: CircularProgressIndicator()),
                            );

                            try {
                              final product = await OpenFoodService.getProductByBarcode(result);
                              Navigator.pop(context);

                              if (product != null) {
                                setState(() {
                                  imageScanned = product.imageFrontUrl;
                                  imageFilePicker = null;

                                  barcodeController.text = result;
                                  nameController.text = product.productName ?? product.genericName ?? '';
                                  descriptionController.text = product.brands ?? '';
                                });
                              } else {
                                Navigator.pop(context);
                                showAwesomeSnackBar(
                                  context,
                                  title: AppLocalizations.of(context)!.warning,
                                  message: AppLocalizations.of(context)!.product_not_found,
                                  contentType: asc.ContentType.warning,
                                );
                              }
                            } catch (_) {
                              Navigator.pop(context);
                              showAwesomeSnackBar(
                                context,
                                title: AppLocalizations.of(context)!.error,
                                message: AppLocalizations.of(context)!.unexpected_error_finding_product,
                                contentType: asc.ContentType.failure,
                              );
                            }
                          }
                        },
                      ),
                    const SizedBox(height: 10),

                    // ---------- CAMPO DE CÓDIGO DE BARRAS ----------
                    if (barcodeController.text.isNotEmpty)
                      TextField(
                          controller: barcodeController, readOnly: true),
                    const SizedBox(height: 10),
                    // ---------- NOMBRE ----------
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.name,
                        suffixIcon: nameTouched
                            ? (nameValid
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          nameTouched = true;
                          nameValid = value.trim().isNotEmpty;
                        });
                      },
                    ),

                    if (nameTouched && !nameValid)
                      Text(AppLocalizations.of(context)!.name_error_message,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),
                    // ---------- DESCRIPCION ----------
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.description,
                        suffixIcon:
                            const Icon(Icons.check_circle, color: Colors.green),
                      ),
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 10),
                    // ---------- PRECIO ----------
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.price,
                        suffixIcon: priceTouched
                            ? (priceValid
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final input = value.trim().replaceAll(',', '.');
                        setState(() {
                          priceTouched = true;
                          priceValid = double.tryParse(input) != null;
                        });
                      },
                    ),
                    if (priceTouched && !priceValid)
                      Text(AppLocalizations.of(context)!.price_error_message,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),
                    // ---------- SUPERMERCADO ----------
                    DropdownButtonFormField<String>(
                      value: selectedSupermarket,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.supermarket,
                        suffixIcon: supermarketTouched
                            ? (supermarketValid
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      hint:
                          Text(AppLocalizations.of(context)!.selectSupermarket),
                      items: supermarketsList.map((s) {
                        return DropdownMenuItem<String>(
                          value: s,
                          child: SizedBox(
                            width: double.infinity,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.grey, width: 0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  Text(s, style: const TextStyle(fontSize: 16)),
                            ),
                          ),
                        );
                      }).toList(),
                      selectedItemBuilder: (context) {
                        return supermarketsList.map((s) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child:
                                Text(s, style: const TextStyle(fontSize: 16)),
                          );
                        }).toList();
                      },
                      onChanged: (String? value) {
                        setState(() {
                          supermarketTouched = true;
                          selectedSupermarket = value;
                          creatingSupermarket =
                              (value == "Nuevo supermercado" ||
                                  value == "New supermarket");
                          supermarketValid =
                              value != null && value.trim().isNotEmpty;
                        });
                      },
                    ),
                    if (supermarketTouched && !supermarketValid)
                      Text(
                          AppLocalizations.of(context)!
                              .supermarket_error_message,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),

                    if (creatingSupermarket)
                      TextField(
                        controller: newSupermarketController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!
                              .selectSupermarketName,
                          suffixIcon:
                              newSupermarketController.text.isNotEmpty
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : const Icon(Icons.cancel, color: Colors.red),
                        ),
                        onChanged: (value) {
                          setState(() {
                            supermarketValid = value.trim().isNotEmpty;
                          });
                        },
                      ),
                    const SizedBox(height: 10),

                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey[700]!, width: 0.8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.photo_library,
                                        color: Colors.green, size: 28),
                                    tooltip: AppLocalizations.of(context)!
                                        .select_photo,
                                    onPressed: () async {
                                      final file = await ImagePickerHelper
                                          .imageFromGallery();
                                      if (file != null) {
                                        setState(() {
                                          imageFilePicker = file;
                                          imageScanned = null;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey[700]!, width: 0.8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.camera_alt,
                                        color: Colors.green, size: 28),
                                    tooltip: isMobile
                                        ? AppLocalizations.of(context)!
                                            .open_camera
                                        : AppLocalizations.of(context)!.paste_image_from_clipboard,
                                    onPressed: () async {
                                      final file = await ImagePickerHelper.imageFromClipboard();
                                      if (file != null) {
                                        setState(() {
                                          imageFilePicker = file;
                                          imageScanned = null;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // ---------- PREVIEW DE LA IMAGEN ----------
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: Builder(
                                builder: (_) {
                                  if (imageFilePicker != null) {
                                    return Image.file(
                                      imageFilePicker!,
                                      fit: BoxFit.contain,
                                    );
                                  } else if (imageScanned != null) {
                                    return Image.network(
                                      imageScanned!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: Icon(Icons.broken_image,
                                              size: 50, color: Colors.white70),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          size: 60,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ---------- ACCIONES (Cancelar / Guardar) ----------
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final String name =
                        capitalize(nameController.text.trim());
                    final String description =
                        capitalize(descriptionController.text.trim());
                    final String priceInput =
                        priceController.text.trim().replaceAll(',', '.');
                    final double? parsedPrice = double.tryParse(priceInput);
                    final String supermarket = creatingSupermarket
                        ? capitalize(newSupermarketController.text.trim())
                        : capitalize(selectedSupermarket ?? '');
                    final String? barcode =
                        barcodeController.text.isEmpty
                            ? null
                            : barcodeController.text;

                    setState(() {
                      nameTouched = true;
                      priceTouched = true;
                      supermarketTouched = true;

                      nameValid = name.isNotEmpty;
                      priceValid = parsedPrice != null;
                      supermarketValid = supermarket.isNotEmpty;
                    });

                    if (!nameValid ||
                        !priceValid ||
                        !supermarketValid ||
                        parsedPrice == null) {
                      return;
                    }
                    if (barcode != null && barcode.isNotEmpty && productProvider.existsWithBarCode(barcode)) {
                      Navigator.pop(dialogCtx);
                      showAwesomeSnackBar(
                        dialogCtx,
                        title: AppLocalizations.of(context)!.error,
                        message: AppLocalizations.of(context)!
                            .barcode_already_registered,
                        contentType: asc.ContentType.failure,
                      );
                      return;
                    }

                    final double price = parsedPrice;
                    final userUuid = context.read<UserProvider>().uuid!;
                    String imageUrl = '';

                    if (imageFilePicker != null) {
                      final bytes = await imageFilePicker!.readAsBytes();
                      final fileName = normalizeImageName(name);
                      final path = 'productos/$userUuid/$fileName.jpg';

                      await Supabase.instance.client.storage
                          .from('fotos')
                          .uploadBinary(path, bytes,
                              fileOptions:
                                  const FileOptions(contentType: 'image/jpeg'));

                      imageUrl = Supabase.instance.client.storage
                          .from('fotos')
                          .getPublicUrl(path);
                    } else if (imageScanned != null) {
                      imageUrl = imageScanned!;
                    }

                    final newProduct = ProductModel(
                      id: null,
                      name: name,
                      description: description,
                      price: price,
                      supermarket: supermarket,
                      userUuid: userUuid,
                      barCode: barcode,
                      photo: imageUrl,
                    );

                    productProvider.addLocalProduct(newProduct);
                    Navigator.of(dialogContext).pop();

                    try {
                      await productProvider.createProduct(newProduct);
                      showAwesomeSnackBar(
                        context,
                        title: AppLocalizations.of(context)!.success,
                        message:
                            AppLocalizations.of(context)!.product_created_ok,
                        contentType: asc.ContentType.success,
                      );
                    } catch (e) {
                      showAwesomeSnackBar(
                        context,
                        title: AppLocalizations.of(context)!.error,
                        message:
                            AppLocalizations.of(context)!.product_created_error,
                        contentType: asc.ContentType.failure,
                      );
                    }
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

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final productsBySupermarket  = productProvider.groupedProducts;
    return Scaffold(
      // ---------- APP BAR ----------
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.products,
          style: const TextStyle(
              fontSize: 30,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      // ---------- BODY ----------
      body: productProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : productProvider.groupedProducts.isEmpty
          ? const ProductsPlaceholder()
          : ListView(
        children: productProvider.groupedProducts.entries.map((entry) {
          final supermarket = entry.key;
          final products = entry.value;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.grey.shade600, width: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        color: Theme.of(context).colorScheme.surface,
                      ),

                      // ---------- SECCIÓN DE SUPERMERCADO ----------
                      child: ExpansionTile(
                        maintainState: true,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Container(
                          constraints: const BoxConstraints(
                            minHeight: 51,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            maxLines: 1,
                            supermarket,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),

                        // ---------- LISTA DE PRODUCTOS ----------
                        children: products.map((product) {
                          return Column(
                            children: [
                              SizedBox(
                                height: 85,
                                child: Center(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    // Miniatura del producto
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: AspectRatio(
                                        aspectRatio: 1.4,
                                        child: (product.photo.isNotEmpty)
                                            ? Image.network(
                                          product.photo,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.image_not_supported,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        )
                                            : const Icon(
                                          Icons.image_outlined,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    // Nombre del producto
                                    title: Text(
                                      maxLines: 2,
                                      product.name,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),

                                    // ---------- ACCIONES (añadir / editar / eliminar) ----------
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Añadir a la lista de la compra
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          constraints: const BoxConstraints(
                                            minWidth: 35,
                                            minHeight: 35,
                                          ),
                                          iconSize: 22,
                                          onPressed: () async {
                                            try {
                                              await context
                                                  .read<ShoppingListProvider>()
                                                  .addToShoppingList(
                                                      product.id!,
                                                      product.price,
                                                      product.name,
                                                      product.supermarket);
                                              showAwesomeSnackBar(
                                                context,
                                                title: AppLocalizations.of(
                                                        context)!
                                                    .success,
                                                message: AppLocalizations.of(
                                                        context)!
                                                    .snackBarAddedProduct,
                                                contentType:
                                                    asc.ContentType.success,
                                              );
                                            } catch (_) {
                                              showAwesomeSnackBar(
                                                context,
                                                title: AppLocalizations.of(
                                                        context)!
                                                    .success,
                                                message: AppLocalizations.of(
                                                        context)!
                                                    .snackBarRepeatedProduct,
                                                contentType:
                                                    asc.ContentType.warning,
                                              );
                                            }
                                          },
                                          padding: EdgeInsets.zero,
                                        ),

                                        // Editar producto
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          constraints: const BoxConstraints(
                                            minWidth: 35,
                                            minHeight: 35,
                                          ),
                                          iconSize: 22,
                                          onPressed: () {
                                            showEditDialog(context, product);
                                          },
                                          padding: EdgeInsets.zero,
                                        ),

                                        // Eliminar producto
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          constraints: const BoxConstraints(
                                            minWidth: 35,
                                            minHeight: 35,
                                          ),
                                          iconSize: 22,
                                          color: Colors.red.shade400,
                                          onPressed: () {
                                            showDeleteDialog(
                                                context, product.id!);
                                          },
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Separador entre productos
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
                  }).toList(),
                ),
      // ---------- BOTÓN FLOTANTE ----------
      floatingActionButton: FloatingActionButton(
        heroTag: "addProducts",
        onPressed: () {
          showCreateDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}