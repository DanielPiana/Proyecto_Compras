import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
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

                final backupProduct =
                productProvider.productos.firstWhere((p) => p.id == productId);

                productProvider.removeProductoLocal(productId);

                Navigator.of(dialogContext).pop();

                try {
                  if (isLastProduct) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message:
                      AppLocalizations.of(context)!.product_deleted_ok,
                      contentType: asc.ContentType.success,
                    );
                  }

                  await productProvider.eliminarProducto(context, productId);

                  if (!isLastProduct && context.mounted) {
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message:
                      AppLocalizations.of(context)!.product_deleted_ok,
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
    final TextEditingController nombreController =
    TextEditingController(text: producto.nombre);
    final TextEditingController descripcionController =
    TextEditingController(text: producto.descripcion);
    final TextEditingController precioController =
    TextEditingController(text: producto.precio.toString());

    final List<String> supermercados =
    await context.read<ProductoProvider>().obtenerSupermercados();
    String supermercadoSeleccionado = producto.supermercado;

    File? nuevaImagenSeleccionada;

    bool nombreValido = producto.nombre.trim().isNotEmpty;
    bool descripcionValida = true;
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
                        suffixIcon: const Icon(Icons.check_circle, color: Colors.green),
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

                    // ---------- SELECCIÓN DE FOTO ----------
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.image),
                        label: Text(AppLocalizations.of(context)!.select_photo),
                        onPressed: () async {
                          File? imagen;
                          if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(
                                source: ImageSource.gallery);
                            if (pickedFile != null) {
                              imagen = File(pickedFile.path);
                            }
                          } else {
                            final result = await FilePicker.platform
                                .pickFiles(type: FileType.image);
                            if (result != null &&
                                result.files.single.path != null) {
                              imagen = File(result.files.single.path!);
                            }
                          }
                          if (imagen != null) {
                            setState(() {
                              nuevaImagenSeleccionada = imagen;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (nuevaImagenSeleccionada != null)
                      Center(
                        child: Image.file(
                          nuevaImagenSeleccionada!,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (producto.foto.isNotEmpty)
                      Center(
                        child: Image.network(
                          producto.foto,
                          height: 100,
                          fit: BoxFit.cover,
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
                    final String nuevoNombre = nombreController.text.trim();
                    final String nuevaDescripcion =
                    descripcionController.text.trim();
                    final String precioInput =
                    precioController.text.trim().replaceAll(',', '.');
                    final double? nuevoPrecioParsed =
                    double.tryParse(precioInput);

                    if (!nombreValido ||
                        !descripcionValida ||
                        !precioValido ||
                        !supermercadoValido ||
                        nuevoPrecioParsed == null) {
                      return;
                    }

                    final double nuevoPrecio = nuevoPrecioParsed;
                    String urlImagen = producto.foto;

                    if (nuevaImagenSeleccionada != null) {
                      final bytes =
                      await nuevaImagenSeleccionada!.readAsBytes();
                      final nombreArchivo =
                          '${nuevoNombre}_${Random().nextInt(9999).toString().padLeft(4, '0')}';
                      final path =
                          'productos/${producto.usuarioUuid}/$nombreArchivo.jpg';

                      await Supabase.instance.client.storage
                          .from('fotos')
                          .uploadBinary(path, bytes,
                          fileOptions:
                          const FileOptions(contentType: 'image/jpeg'));

                      urlImagen = Supabase.instance.client.storage
                          .from('fotos')
                          .getPublicUrl(path);
                    }

                    final productoActualizado = ProductoModel(
                      id: producto.id,
                      codBarras: producto.codBarras,
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

    String? imagenActualUrl; // Imagen de escaneo
    File? imagenActualFile;  // Imagen seleccionada del usuario
    String? urlImagenTemporal;
    String? supermercadoSeleccionado;
    bool creandoSupermercado = false;
    File? imagenSeleccionada;

    bool nombreValido = false;
    bool descripcionValida = true;
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
                    ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text("Escanear código de barras"),
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
                            OpenFoodAPIConfiguration.userAgent = UserAgent(
                              name: 'ProyectoCompras',
                              version: '1.0.0',
                              system: 'Flutter',
                            );

                            final config = ProductQueryConfiguration(
                              result,
                              language: OpenFoodFactsLanguage.SPANISH,
                              fields: [
                                ProductField.ALL,
                                ProductField.IMAGE_FRONT_URL,
                              ],
                              version: ProductQueryVersion.v3,
                            );

                            final ProductResultV3 response =
                            await OpenFoodAPIClient.getProductV3(config);

                            Navigator.pop(context);

                            if (response.product != null) {
                              final product = response.product!;
                              final imageUrl = product.imageFrontUrl;

                              if (imageUrl != null && imageUrl.isNotEmpty) {
                                setState(() {
                                  imagenActualUrl = imageUrl;
                                  imagenActualFile = null;
                                });
                              }

                              print('--- 📦 PRODUCTO ESCANEADO ---');
                              print('Nombre: ${product.productName}');
                              print('Nombre genérico: ${product.genericName}');
                              print('Marca: ${product.brands}');
                              print('Categorías: ${product.categories}');
                              print('Descripción: ${product.ingredientsText}');
                              print('Código de barras: ${product.barcode}');
                              print('Imagen: ${product.imageFrontUrl}');
                              print('Países: ${product.countries}');
                              print('Cantidad: ${product.quantity}');
                              print('Ingredientes: ${product.ingredientsText}');
                              print('--- 🔚 FIN DEL PRODUCTO ---');

                              setState(() {
                                codigoBarrasController.text = result;
                                nombreController.text =
                                    product.productName ?? product.genericName ?? '';
                                descripcionController.text =
                                    product.ingredientsText ?? product.genericName ?? '';

                                if (imageUrl != null && imageUrl.isNotEmpty) {
                                  urlImagenTemporal = imageUrl;
                                }
                              });

                              showAwesomeSnackBar(
                                context,
                                title: "Éxito",
                                message: "Producto encontrado y completado automáticamente",
                                contentType: asc.ContentType.success,
                              );
                            } else {
                              showAwesomeSnackBar(
                                context,
                                title: "No encontrado",
                                message:
                                "No se encontró información del producto en OpenFoodFacts",
                                contentType: asc.ContentType.warning,
                              );
                            }
                          } catch (e) {
                            Navigator.pop(context);
                            showAwesomeSnackBar(
                              context,
                              title: "Error",
                              message: "Error al obtener datos del producto",
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
                        controller: codigoBarrasController,
                        readOnly: true,
                        decoration: const InputDecoration(labelText: "Código de barras"),
                      ),

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
                        suffixIcon: const Icon(Icons.check_circle, color: Colors.green),
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
                      value: supermercadoSeleccionado,
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
                          ElevatedButton.icon(
                            icon: const Icon(Icons.image),
                            label: Text(AppLocalizations.of(context)!.select_photo),
                            onPressed: () async {
                              File? imagen;
                              if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
                                final picker = ImagePicker();
                                final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                                if (pickedFile != null) {
                                  imagen = File(pickedFile.path);
                                }
                              } else {
                                final result = await FilePicker.platform.pickFiles(type: FileType.image);
                                if (result != null && result.files.single.path != null) {
                                  imagen = File(result.files.single.path!);
                                }
                              }

                              if (imagen != null) {
                                setState(() {
                                  imagenActualFile = imagen;
                                  imagenActualUrl = null;
                                });
                              }
                            },

                          ),
                          const SizedBox(height: 10),

                          // ---------- PREVIEW DE LA IMAGEN ----------
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 180, // 👈 un poco más alta
                              width: double.infinity,
                              child: Builder(
                                builder: (_) {
                                  if (imagenActualFile != null) {
                                    return Image.file(
                                      imagenActualFile!,
                                      fit: BoxFit.contain,
                                    );
                                  } else if (imagenActualUrl != null) {
                                    return Image.network(
                                      imagenActualUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: Icon(Icons.broken_image, size: 50, color: Colors.white70),
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
                    final String nombre =
                    capitalize(nombreController.text.trim());
                    final String descripcion =
                    capitalize(descripcionController.text.trim());
                    final String precioInput =
                    precioController.text.trim().replaceAll(',', '.');
                    final double? precioParsed = double.tryParse(precioInput);
                    final String supermercado = creandoSupermercado
                        ? capitalize(nuevoSupermercadoController.text.trim())
                        : capitalize(supermercadoSeleccionado ?? '');

                    setState(() {
                      nombreTouched = true;
                      precioTouched = true;
                      supermercadoTouched = true;

                      nombreValido = nombre.isNotEmpty;
                      descripcionValida = descripcion.isNotEmpty;
                      precioValido = precioParsed != null;
                      supermercadoValido = supermercado.isNotEmpty;
                    });

                    if (!nombreValido ||
                        !descripcionValida ||
                        !precioValido ||
                        !supermercadoValido ||
                        precioParsed == null) {
                      return;
                    }

                    final double precio = precioParsed;
                    final uuidUsuario = context.read<UserProvider>().uuid!;
                    String urlImagen = '';

                    if (imagenActualFile != null) {
                      // Subimos la imagen elegida manualmente
                      final bytes = await imagenActualFile!.readAsBytes();
                      final nombreArchivo = '${nombre}_${Random().nextInt(9999).toString().padLeft(4, '0')}';
                      final path = 'productos/$uuidUsuario/$nombreArchivo.jpg';

                      await Supabase.instance.client.storage
                          .from('fotos')
                          .uploadBinary(path, bytes,
                          fileOptions: const FileOptions(contentType: 'image/jpeg'));

                      urlImagen = Supabase.instance.client.storage.from('fotos').getPublicUrl(path);
                    } else if (imagenActualUrl != null) {
                      // Imagen remota (OpenFoodFacts)
                      urlImagen = imagenActualUrl!;
                    }


                    final nuevoProducto = ProductoModel(
                      id: null,
                      nombre: nombre,
                      descripcion: descripcion,
                      precio: precio,
                      supermercado: supermercado,
                      usuarioUuid: uuidUsuario,
                      codBarras: '',
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
              fontWeight: FontWeight.bold
          ),
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
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade600, width: 0.8),
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
                            contentPadding: const EdgeInsets.symmetric(
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
                                  const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                                ),
                              ),
                            ),

                            // Nombre del producto
                            title: Text(
                              producto.nombre,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold
                              ),
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
                                      await context.read<CompraProvider>().agregarACompra(
                                          producto.id!,
                                          producto.precio,
                                          producto.nombre,
                                          producto.supermercado);
                                      showAwesomeSnackBar(
                                        context,
                                        title: AppLocalizations.of(context)!.success,
                                        message: AppLocalizations.of(context)!
                                            .snackBarAddedProduct,
                                        contentType: asc.ContentType.success,
                                      );
                                    } catch (_) {
                                      showAwesomeSnackBar(
                                        context,
                                        title: AppLocalizations.of(context)!.success,
                                        message: AppLocalizations.of(context)!
                                            .snackBarRepeatedProduct,
                                        contentType: asc.ContentType.warning,
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
                                    dialogoEliminacion(context, producto.id!);
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
      // floatingActionButton: SpeedDial(
      //   heroTag: 'fab_productos',
      //   animatedIcon: AnimatedIcons.add_event,
      //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      //   buttonSize: const Size(58, 58),
      //   children: [
      //     SpeedDialChild(
      //       child: const Icon(Icons.create),
      //       label: AppLocalizations.of(context)!.manually_create_product,
      //       onTap: () {
      //         dialogoCreacion(context);
      //       }
      //     ),
      //     SpeedDialChild(
      //       child: const Icon(Icons.barcode_reader),
      //       label: AppLocalizations.of(context)!.scan_barcode,
      //       onTap: () {
      //         // TODO Metodo para escanear codigo de barras
      //       }
      //     ),
      //   ],
      // ),

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
