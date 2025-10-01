import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/utils/capitalize.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/compraProvider.dart';
import '../Providers/productoProvider.dart';
import '../Providers/userProvider.dart';
import '../Widgets/awesomeSnackbar.dart';
import '../l10n/app_localizations.dart';
import '../models/productoModel.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;

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
  /// - [idProducto]: Identificador del producto a eliminar.
  ///
  /// Retorna:
  /// - `void` (no retorna nada).
  void dialogoEliminacion(BuildContext context, int idProducto) {
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
                final provider = context.read<ProductoProvider>();

                final backup =
                provider.productos.firstWhere((p) => p.id == idProducto);

                provider.removeProductoLocal(idProducto);

                Navigator.of(dialogContext).pop();

                try {
                  await provider.eliminarProducto(context, idProducto);

                  showAwesomeSnackBar(
                    context,
                    title: AppLocalizations.of(context)!.success,
                    message: AppLocalizations.of(context)!.product_deleted_ok,
                    contentType: asc.ContentType.success,
                  );
                } catch (e) {
                  debugPrint("Error al eliminar producto: $e");
                  provider.addProductoLocal(backup);

                  showAwesomeSnackBar(
                    context,
                    title: 'Error',
                    message:
                    AppLocalizations.of(context)!.product_deleted_error,
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
    bool descripcionValida = producto.descripcion.trim().isNotEmpty;
    bool precioValido = true;
    bool supermercadoValido = producto.supermercado.trim().isNotEmpty;

    bool nombreTouched = false;
    bool descripcionTouched = false;
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
                        suffixIcon: descripcionTouched
                            ? (descripcionValida
                            ? const Icon(Icons.check_circle,
                            color: Colors.green)
                            : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          descripcionTouched = true;
                          descripcionValida = value.trim().isNotEmpty;
                        });
                      },
                    ),
                    if (descripcionTouched && !descripcionValida)
                      Text(
                          AppLocalizations.of(context)!
                              .description_error_message,
                          style: const TextStyle(color: Colors.red)),
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
                      Image.file(nuevaImagenSeleccionada!,
                          height: 100, fit: BoxFit.cover)
                    else if (producto.foto.isNotEmpty)
                      Image.network(producto.foto,
                          height: 100, fit: BoxFit.cover),
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
    final TextEditingController nuevoSupermercadoController =
    TextEditingController();

    String? supermercadoSeleccionado;
    bool creandoSupermercado = false;
    File? imagenSeleccionada;

    bool nombreValido = false;
    bool descripcionValida = false;
    bool precioValido = false;
    bool supermercadoValido = false;

    bool nombreTouched = false;
    bool descripcionTouched = false;
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

                    TextField(
                      controller: descripcionController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.description,
                        suffixIcon: descripcionTouched
                            ? (descripcionValida
                            ? const Icon(Icons.check_circle,
                            color: Colors.green)
                            : const Icon(Icons.cancel, color: Colors.red))
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          descripcionTouched = true;
                          descripcionValida = value.trim().isNotEmpty;
                        });
                      },
                    ),
                    if (descripcionTouched && !descripcionValida)
                      Text(
                          AppLocalizations.of(context)!
                              .description_error_message,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),

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
                              imagenSeleccionada = imagen;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (imagenSeleccionada != null)
                      Image.file(
                        imagenSeleccionada!,
                        height: 100,
                        fit: BoxFit.cover,
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
                      descripcionTouched = true;
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

                    if (imagenSeleccionada != null) {
                      final bytes = await imagenSeleccionada!.readAsBytes();
                      final nombreArchivo =
                          '${nombre}_${Random().nextInt(9999).toString().padLeft(4, '0')}';
                      final path = 'productos/$uuidUsuario/$nombreArchivo.jpg';

                      await Supabase.instance.client.storage
                          .from('fotos')
                          .uploadBinary(path, bytes,
                          fileOptions:
                          const FileOptions(contentType: 'image/jpeg'));

                      urlImagen = Supabase.instance.client.storage
                          .from('fotos')
                          .getPublicUrl(path);
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
      body: providerProducto.productos
          .isEmpty // SI NO HAY PRODUCTOS MOSTRAMOS UN CIRCULO DE CARGA
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : ListView(
        // SI HAY PRODUCTOS, MOSTRAMOS UNA LISTA
        children: productosPorSupermercado.entries.map((entry) {
          final supermercado =
              entry.key; // AQUI OBTENEMOS EL NOMBRE DEL SUPERMERCADO
          final productos = entry
              .value; // AQUI OBTENEMOS LA LISTA DE PRODUCTOS DE ESE SUPERMERCADO

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

              // ---------- LISTA DE PRODUCTOS ----------
              children: productos.map((producto) {
                return Column(
                  children: [
                    SizedBox(
                      height: 85,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
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
                      indent: 16,
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
        // BOTON FLOTANTE PARA AÑADIR NUEVO PRODUCTO
        onPressed: () {
          // ABRIMOS EL DIALOGO DE CREACION
          dialogoCreacion(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
