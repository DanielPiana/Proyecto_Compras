import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/utils/capitalize.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/compraProvider.dart';
import '../Providers/productoProvider.dart';
import '../Providers/userProvider.dart';
import '../Widgets/EscanearCodigoBarras.dart';
import '../Widgets/PlaceHolderProductos.dart';
import '../Widgets/awesomeSnackbar.dart';
import '../l10n/app_localizations.dart';
import '../models/productoModel.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;
import 'package:flutter/services.dart';

import '../services/openfood_service.dart';
import '../utils/imageNameNormalizer.dart';
import '../utils/imagePicker.dart';

class Producto extends StatefulWidget {
  const Producto({super.key});

  @override
  State<Producto> createState() => ProductoState();
}

class ProductoState extends State<Producto> {
  late String userId;

  SupabaseClient database = Supabase.instance.client;

  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  final isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /*TODO-----------------INITIALIZE-----------------*/
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<UserProvider>().uuid;
      // SI NO HAY USUARIO, LE MANDAMOS A LA PESTAÑA DE LOGIN
      if (uid != null) {
        setState(() {
          userId = uid;
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
  void dialogoEliminacion(BuildContext context, int productId) {
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
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                AppLocalizations.of(context)!.cancel,
              ),
            ),

            // Eliminar
            TextButton(
              onPressed: () async {
                final productProvider = context.read<ProductoProvider>();
                final allProducts = List.of(productProvider.productos);
                final isLastProduct = allProducts.length == 1;

                final backupProduct = productProvider.productos
                    .firstWhere((p) => p.id == productId);

                productProvider.removeProductoLocal(productId);

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

                  await productProvider.eliminarProducto(context, productId);

                  if (!isLastProduct && context.mounted) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message: AppLocalizations.of(context)!.product_deleted_ok,
                      contentType: asc.ContentType.success,
                    );
                  }
                } catch (error) {
                  productProvider.addProductoLocal(backupProduct);

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
  /// - Al confirmar, se construye un nuevo objeto [ProductoModel] actualizado.
  /// - Se actualiza el producto en la base de datos mediante el [ProductoProvider].
  /// - Si la operación es exitosa, se muestra un snackbar de éxito; si falla, se muestra un snackbar de error.
  ///
  /// Parámetros:
  /// - [context]: Contexto de la aplicación.
  /// - [producto]: Instancia de [ProductoModel] que se desea editar.
  ///
  /// Retorna:
  /// - `void` (no retorna nada).
  ///
  /// Excepciones:
  /// - Puede lanzar errores relacionados con la carga de imágenes o la actualización en Supabase.
  void dialogoEdicion(BuildContext context, ProductoModel producto) async {
    final TextEditingController nombreController = TextEditingController(text: producto.nombre);
    final TextEditingController descripcionController = TextEditingController(text: producto.descripcion);
    final TextEditingController precioController = TextEditingController(text: producto.precio.toString());
    final TextEditingController codigoBarrasController = TextEditingController(text: producto.codBarras);

    final List<String> supermercados = await context.read<ProductoProvider>().obtenerSupermercados();
    String supermercadoSeleccionado = producto.supermercado;

    String? imageScanned = producto.foto.isNotEmpty ? producto.foto : null;
    File? imageFilePicker; // Imagen seleccionada del usuario

    bool nombreValido = producto.nombre.trim().isNotEmpty;
    bool precioValido = true;
    bool supermercadoValido = producto.supermercado.trim().isNotEmpty;

    bool nombreTouched = false;
    bool precioTouched = false;
    bool supermercadoTouched = false;

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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMobile)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(AppLocalizations.of(context)!.scan_barcode),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EscanearCodigoScreen()),
                          );

                          if (result != null && result is String) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(child: CircularProgressIndicator()),
                            );

                            try {
                              final product = await OpenFoodService.obtenerProductoPorCodigo(result);
                              Navigator.pop(context);

                              if (product != null) {

                                setState(() {
                                  imageScanned = product.imageFrontUrl;
                                  imageFilePicker = null;

                                  codigoBarrasController.text = result;
                                  nombreController.text =
                                      product.productName ?? product.genericName ?? '';
                                  descripcionController.text = product.brands ?? '';
                                });

                              } else {
                                showAwesomeSnackBar(
                                  context,
                                  title: "No encontrado",
                                  message: "No se encontró información del producto",
                                  contentType: asc.ContentType.warning,
                                );
                              }
                            } catch (_) {
                              Navigator.pop(context);
                              showAwesomeSnackBar(
                                context,
                                title: "Error",
                                message: "Error al obtener datos",
                                contentType: asc.ContentType.failure,
                              );
                            }
                          }

                        },
                      ),
                    const SizedBox(height: 10),

                    // ---------- CAMPO DE CÓDIGO DE BARRAS ----------
                    if (codigoBarrasController.text.isNotEmpty)
                      TextField(
                          decoration: const InputDecoration(labelText: "Código de barras"),
                          controller: codigoBarrasController, readOnly: true
                      ),
                    const SizedBox(height: 10),
                    // ---------- CAMPO NOMBRE ----------
                    TextField(
                      controller: nombreController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.name,
                        suffixIcon: nombreTouched
                            ? (nombreValido
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          nombreTouched = true;
                          nombreValido = value.trim().isNotEmpty;
                        });
                      },
                    ),
                    if (nombreTouched && !nombreValido)
                      Text(AppLocalizations.of(context)!.name_error_message,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),

                    // ---------- CAMPO DESCRIPCIÓN ----------
                    TextField(
                      controller: descripcionController,
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
                      controller: precioController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.price,
                        suffixIcon: precioTouched
                            ? (precioValido
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final input = value.trim().replaceAll(',', '.');
                        setState(() {
                          precioTouched = true;
                          precioValido = double.tryParse(input) != null;
                        });
                      },
                    ),
                    if (precioTouched && !precioValido)
                      Text(AppLocalizations.of(context)!.price_error_message,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),

                    // ---------- SELECCIÓN SUPERMERCADO ----------
                    DropdownButtonFormField<String>(
                      value: supermercadoSeleccionado,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.supermarket,
                        suffixIcon: supermercadoTouched
                            ? (supermercadoValido
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      items: supermercados.map((s) {
                        return DropdownMenuItem<String>(
                          value: s,
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
                                  Text(s, style: const TextStyle(fontSize: 16)),
                            ),
                          ),
                        );
                      }).toList(),
                      selectedItemBuilder: (context) {
                        return supermercados.map((s) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child:
                                Text(s, style: const TextStyle(fontSize: 16)),
                          );
                        }).toList();
                      },
                      onChanged: (nuevoSuper) {
                        if (nuevoSuper != null) {
                          setState(() {
                            supermercadoTouched = true;
                            supermercadoSeleccionado = nuevoSuper;
                            supermercadoValido = nuevoSuper.trim().isNotEmpty;
                          });
                        }
                      },
                    ),
                    if (supermercadoTouched && !supermercadoValido)
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
                                    border: Border.all(color: Colors.grey[700]!, width: 0.8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.photo_library, color: Colors.green, size: 28),
                                    tooltip: AppLocalizations.of(context)!.select_photo,
                                    onPressed: () async {
                                      final file = await ImagePickerHelper.imageFromGallery();
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
                                    border: Border.all(color: Colors.grey[700]!, width: 0.8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.camera_alt, color: Colors.green, size: 28),
                                    tooltip: isMobile
                                        ? AppLocalizations.of(context)!.open_camera
                                        : "Pegar imagen desde el portapapeles",
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

                          // ---------- PREVIEW IMAGEN ----------
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: Builder(
                                builder: (_) {
                                  if (imageFilePicker != null) {
                                    return Image.file(imageFilePicker!, fit: BoxFit.contain);
                                  } else if (imageScanned != null && imageScanned!.isNotEmpty) {
                                    return Image.network(imageScanned!, fit: BoxFit.contain);
                                  } else {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(Icons.image_outlined, size: 60, color: Colors.white70),
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
                    final String codigoBarras = codigoBarrasController.text;
                    final String nuevoNombre = nombreController.text.trim();
                    final String nuevaDescripcion =
                        descripcionController.text.trim();
                    final String precioInput =
                        precioController.text.trim().replaceAll(',', '.');
                    final double? nuevoPrecioParsed =
                        double.tryParse(precioInput);

                    if (!nombreValido ||
                        !precioValido ||
                        !supermercadoValido ||
                        nuevoPrecioParsed == null) {
                      return;
                    }

                    final double nuevoPrecio = nuevoPrecioParsed;
                    String urlImagen = producto.foto;

                    if (imageFilePicker != null) {
                      final bytes = await imageFilePicker!.readAsBytes();
                      final nombreArchivo = imageNameNormalizer(nuevoNombre);
                      final path = 'productos/${producto.usuarioUuid}/$nombreArchivo.jpg';

                      await Supabase.instance.client.storage
                          .from('fotos')
                          .uploadBinary(path, bytes,
                          fileOptions: const FileOptions(contentType: 'image/jpeg'));

                      urlImagen = Supabase.instance.client.storage
                          .from('fotos')
                          .getPublicUrl(path);
                    }
                    else if (imageScanned != null) {
                      urlImagen = imageScanned!;
                    }


                    final productoActualizado = ProductoModel(
                      id: producto.id,
                      codBarras: codigoBarras,
                      nombre: nuevoNombre,
                      descripcion: nuevaDescripcion,
                      precio: nuevoPrecio,
                      supermercado: supermercadoSeleccionado,
                      usuarioUuid: producto.usuarioUuid,
                      foto: urlImagen,
                    );

                    Navigator.of(dialogContext).pop();

                    try {
                      await context.read<ProductoProvider>().actualizarProducto(
                            productoActualizado,
                            context.read<CompraProvider>(),
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
                        title: 'Error',
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
  /// - Construye un nuevo [ProductoModel] con los datos ingresados.
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
  void dialogoCreacion(BuildContext context) {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController descripcionController = TextEditingController();
    final TextEditingController precioController = TextEditingController();
    final TextEditingController nuevoSupermercadoController = TextEditingController();
    final TextEditingController codigoBarrasController = TextEditingController();

    String? imageScanned; // Imagen de escaneo
    File? imageFilePicker; // Imagen seleccionada del usuario
    String? supermercadoSeleccionado;
    bool creandoSupermercado = false;

    bool nombreValido = false;
    bool precioValido = false;
    bool supermercadoValido = false;

    bool nombreTouched = false;
    bool precioTouched = false;
    bool supermercadoTouched = false;

    final provider = context.read<ProductoProvider>();
    final supermercados = provider.productosPorSupermercado.keys.toList()
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- ESCANEO DE CÓDIGO DE BARRAS ----------
                    if (isMobile)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(AppLocalizations.of(context)!.scan_barcode),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EscanearCodigoScreen()),
                          );

                          if (result != null && result is String) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(child: CircularProgressIndicator()),
                            );

                            try {
                              final product = await OpenFoodService.obtenerProductoPorCodigo(result);
                              Navigator.pop(context);

                              if (product != null) {

                                setState(() {
                                  imageScanned = product.imageFrontUrl;
                                  imageFilePicker = null;

                                  codigoBarrasController.text = result;
                                  nombreController.text =
                                      product.productName ?? product.genericName ?? '';
                                  descripcionController.text = product.brands ?? '';
                                });

                              } else {
                                showAwesomeSnackBar(
                                  context,
                                  title: "No encontrado",
                                  message: "No se encontró información del producto",
                                  contentType: asc.ContentType.warning,
                                );
                              }
                            } catch (_) {
                              Navigator.pop(context);
                              showAwesomeSnackBar(
                                context,
                                title: "Error",
                                message: "Error al obtener datos",
                                contentType: asc.ContentType.failure,
                              );
                            }
                          }

                        },
                      ),
                    const SizedBox(height: 10),

                    // ---------- CAMPO DE CÓDIGO DE BARRAS ----------
                    if (codigoBarrasController.text.isNotEmpty)
                      TextField(
                          controller: codigoBarrasController, readOnly: true),
                    const SizedBox(height: 10),
                    // ---------- NOMBRE ----------
                    TextField(
                      controller: nombreController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.name,
                        suffixIcon: nombreTouched
                            ? (nombreValido
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          nombreTouched = true;
                          nombreValido = value.trim().isNotEmpty;
                        });
                      },
                    ),

                    if (nombreTouched && !nombreValido)
                      Text(AppLocalizations.of(context)!.name_error_message,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),
                    // ---------- DESCRIPCION ----------
                    TextField(
                      controller: descripcionController,
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
                      controller: precioController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.price,
                        suffixIcon: precioTouched
                            ? (precioValido
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final input = value.trim().replaceAll(',', '.');
                        setState(() {
                          precioTouched = true;
                          precioValido = double.tryParse(input) != null;
                        });
                      },
                    ),
                    if (precioTouched && !precioValido)
                      Text(AppLocalizations.of(context)!.price_error_message,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),
                    // ---------- SUPERMERCADO ----------
                    DropdownButtonFormField<String>(
                      initialValue: supermercadoSeleccionado,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.supermarket,
                        suffixIcon: supermercadoTouched
                            ? (supermercadoValido
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      hint:
                          Text(AppLocalizations.of(context)!.selectSupermarket),
                      items: supermercados.map((s) {
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
                        return supermercados.map((s) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child:
                                Text(s, style: const TextStyle(fontSize: 16)),
                          );
                        }).toList();
                      },
                      onChanged: (String? value) {
                        setState(() {
                          supermercadoTouched = true;
                          supermercadoSeleccionado = value;
                          creandoSupermercado =
                              (value == "Nuevo supermercado" ||
                                  value == "New supermarket");
                          supermercadoValido =
                              value != null && value.trim().isNotEmpty;
                        });
                      },
                    ),
                    if (supermercadoTouched && !supermercadoValido)
                      Text(
                          AppLocalizations.of(context)!
                              .supermarket_error_message,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),

                    if (creandoSupermercado)
                      TextField(
                        controller: nuevoSupermercadoController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!
                              .selectSupermarketName,
                          suffixIcon:
                              nuevoSupermercadoController.text.isNotEmpty
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : const Icon(Icons.cancel, color: Colors.red),
                        ),
                        onChanged: (value) {
                          setState(() {
                            supermercadoValido = value.trim().isNotEmpty;
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
                                      final file = await ImagePickerHelper.imageFromGallery();
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
                                        : "Pegar imagen desde el portapapeles",
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
                    final String nombre = capitalize(nombreController.text.trim());
                    final String descripcion = capitalize(descripcionController.text.trim());
                    final String precioInput = precioController.text.trim().replaceAll(',', '.');
                    final double? precioParsed = double.tryParse(precioInput);
                    final String supermercado = creandoSupermercado
                        ? capitalize(nuevoSupermercadoController.text.trim())
                        : capitalize(supermercadoSeleccionado ?? '');
                    final String codigoBarras = codigoBarrasController.text.isEmpty ? '' : codigoBarrasController.text;

                    setState(() {
                      nombreTouched = true;
                      precioTouched = true;
                      supermercadoTouched = true;

                      nombreValido = nombre.isNotEmpty;
                      precioValido = precioParsed != null;
                      supermercadoValido = supermercado.isNotEmpty;
                    });

                    if (!nombreValido ||
                        !precioValido ||
                        !supermercadoValido ||
                        precioParsed == null) {
                      return;
                    }
                    if (provider.existsWithBarCode(codigoBarras)) {
                      Navigator.pop(dialogCtx);
                      showAwesomeSnackBar(
                        dialogCtx,
                        title: AppLocalizations.of(context)!.error,
                        message:AppLocalizations.of(context)!.barcode_already_registered,
                        contentType: asc.ContentType.failure,
                      );
                      return;
                    }

                    final double precio = precioParsed;
                    final uuidUsuario = context.read<UserProvider>().uuid!;
                    String urlImagen = '';

                    if (imageFilePicker != null) {
                      final bytes = await imageFilePicker!.readAsBytes();
                      final nombreArchivo = imageNameNormalizer(nombre);
                      final path = 'productos/$uuidUsuario/$nombreArchivo.jpg';

                      await Supabase.instance.client.storage
                          .from('fotos')
                          .uploadBinary(path, bytes,
                              fileOptions:
                                  const FileOptions(contentType: 'image/jpeg'));

                      urlImagen = Supabase.instance.client.storage
                          .from('fotos')
                          .getPublicUrl(path);
                    } else if (imageScanned != null) {
                      urlImagen = imageScanned!;
                    }

                    final nuevoProducto = ProductoModel(
                      id: null,
                      nombre: nombre,
                      descripcion: descripcion,
                      precio: precio,
                      supermercado: supermercado,
                      usuarioUuid: uuidUsuario,
                      codBarras: codigoBarras,
                      foto: urlImagen,
                    );

                    provider.addProductoLocal(nuevoProducto);
                    Navigator.of(dialogContext).pop();

                    try {
                      await provider.crearProducto(nuevoProducto);
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
                        title: "Error",
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
    final providerProducto = context.watch<ProductoProvider>();
    final productosPorSupermercado = providerProducto.productosPorSupermercado;
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
      body: providerProducto.isLoading
          ? const Center(child: CircularProgressIndicator())
          : providerProducto.productos.isEmpty
              ? const PlaceholderProductos()
              : ListView(
                  // SI HAY PRODUCTOS, MOSTRAMOS UNA LISTA
                  children: productosPorSupermercado.entries.map((entry) {
                    final supermercado = entry.key;
                    final productos = entry.value;

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
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Container(
                          constraints: const BoxConstraints(
                            minHeight: 51,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            supermercado,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),

                        // ---------- LISTA DE PRODUCTOS ----------
                        children: productos.map((producto) {
                          return Column(
                            children: [
                              SizedBox(
                                height: 85,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Center(
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      // Miniatura del producto
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: AspectRatio(
                                          aspectRatio: 1.4,
                                          child: Image.network(
                                            producto.foto,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                    Icons.image_not_supported,
                                                    size: 50,
                                                    color: Colors.grey),
                                          ),
                                        ),
                                      ),

                                      // Nombre del producto
                                      title: Text(
                                        producto.nombre,
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
                                                    .read<CompraProvider>()
                                                    .agregarACompra(
                                                        producto.id!,
                                                        producto.precio,
                                                        producto.nombre,
                                                        producto.supermercado);
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
                                              dialogoEdicion(context, producto);
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
                                              dialogoEliminacion(
                                                  context, producto.id!);
                                            },
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
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
          dialogoCreacion(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
