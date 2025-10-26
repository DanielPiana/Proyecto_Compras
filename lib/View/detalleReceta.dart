import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/detalleRecetaProvider.dart';
import 'package:proyectocompras/utils/capitalize.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/compraProvider.dart';
import '../Providers/pasosRecetaProvider.dart';
import '../Providers/productoProvider.dart';
import '../Providers/productosRecetaProvider.dart';
import '../Providers/recetaProvider.dart';
import '../Widgets/awesomeSnackbar.dart';
import '../Widgets/stepperPersonalizado.dart';
import '../l10n/app_localizations.dart';
import '../models/PasoReceta.dart';
import '../models/recetaModel.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;

class DetalleReceta extends StatefulWidget {
  final RecetaModel receta;

  const DetalleReceta({super.key, required this.receta});

  @override
  State<DetalleReceta> createState() => _DetalleRecetaState();
}

class _DetalleRecetaState extends State<DetalleReceta> {
  File? nuevaFotoFile;

  late RecetaModel receta;

  String nuevoNombre = "";
  String nuevoTituloPaso = "";
  String nuevaDescripcionPaso = "";
  String nuevaFotoUrl = "";
  int pasoActualizar = -1;
  bool cambios = false;

  bool editandoNombre = false;
  final nombreController = TextEditingController();
  final _focusNode = FocusNode();

  final tituloController = TextEditingController();
  final descripcionController = TextEditingController();

  List<PasoReceta> pasos = [];
  bool estaCargandoPasos = true;

  @override
  void initState() {
    super.initState();
    receta = widget.receta;
    nombreController.text = receta.nombre;
  }

  /// METODO PARA OBTENER UNA LISTA DE LOS PRODUCTOS
  Future<List<Map<String, dynamic>>> obtenerProductos() async {
    final res = await Supabase.instance.client.from('productos').select();
    return List<Map<String, dynamic>>.from(res);
  }

  /// Guarda los productos seleccionados para una receta en la base de datos.
  ///
  /// Flujo principal:
  /// - Busca qué productos tiene actualmente guardados la receta en la tabla `receta_producto`.
  /// - Compara esos productos con los que el usuario ha seleccionado ahora.
  /// - Calcula:
  ///   - [insertar]: los productos nuevos que hay que añadir.
  ///   - [borrar]: los productos que ya no están seleccionados y hay que quitar.
  /// - Añade a la base de datos los productos nuevos.
  /// - Elimina los productos que ya no pertenecen a la receta.
  Future<void> guardarProductosEnReceta(
      int recetaId, Set<int> nuevosSeleccionados) async {
    final res = await Supabase.instance.client
        .from('receta_producto')
        .select('idproducto')
        .eq('idreceta', recetaId);

    final actuales = Set<int>.from(res.map((r) => r['idproducto'] as int));

    final insertar = nuevosSeleccionados.difference(actuales);
    final borrar = actuales.difference(nuevosSeleccionados);

    for (final id in insertar) {
      await Supabase.instance.client.from('receta_producto').insert({
        'idreceta': recetaId,
        'idproducto': id,
      });
    }

    for (final id in borrar) {
      await Supabase.instance.client
          .from('receta_producto')
          .delete()
          .eq('idreceta', recetaId)
          .eq('idproducto', id);
    }
  }

  /// Muestra un cuadro de diálogo para seleccionar productos y guardarlos en una receta.
  ///
  /// Flujo principal:
  /// - Obtiene la lista de productos disponibles desde el ProductoProvider.
  /// - Obtiene los productos ya asociados a la receta desde el ProductosRecetaProvider.
  /// - Crea un cuadro de diálogo con una lista de productos y casillas de verificación.
  /// - El usuario puede marcar o desmarcar productos para añadir o quitar.
  /// - Al pulsar Guardar:
  ///   - Se sincroniza la selección con la base de datos llamando a syncProductos.
  ///   - Si todo va bien, muestra un mensaje de éxito.
  ///   - Si ocurre un error, muestra un mensaje de error.
  /// - Al pulsar Cancelar, simplemente cierra el diálogo sin guardar cambios.
  void mostrarDialogoSeleccionProductos(BuildContext context) async {
    final productoProvider = context.read<ProductoProvider>();
    final recetaProvider = context.read<ProductosRecetaProvider>();
    final productosDisponibles = productoProvider.productos;

    final Set<int> seleccionados =
        recetaProvider.productos.map((p) => p.id!).toSet();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.select_products),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: productosDisponibles.length,
                itemBuilder: (_, index) {
                  final producto = productosDisponibles[index];
                  return CheckboxListTile(
                    value: seleccionados.contains(producto.id),
                    title: Text(producto.nombre),
                    onChanged: (bool? checked) {
                      setStateDialog(() {
                        if (checked == true) {
                          seleccionados.add(producto.id!);
                        } else {
                          seleccionados.remove(producto.id!);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(AppLocalizations.of(context)!.cancel),
                        ),
                        ElevatedButton(
                          child: Text(AppLocalizations.of(context)!.save),
                          onPressed: () async {
                            try {
                              await recetaProvider.syncProductos(context, seleccionados);

                              Navigator.pop(context);
                              showAwesomeSnackBar(
                                context,
                                title: AppLocalizations.of(context)!.success,
                                message: AppLocalizations.of(context)!.products_linked_ok,
                                contentType: asc.ContentType.success,
                              );
                            } catch (e) {
                              Navigator.pop(context);
                              showAwesomeSnackBar(
                                context,
                                title: 'Error',
                                message:
                                AppLocalizations.of(context)!.products_linked_error,
                                contentType: asc.ContentType.failure,
                              );
                            }
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton.icon(
                  label: Text(
                      AppLocalizations.of(context)!.add_ingredients_to_list),
                  onPressed: () async {
                    final compraProvider = context.read<CompraProvider>();
                    final productoProvider = context.read<ProductoProvider>();

                    final productosMarcados = productoProvider.productos
                        .where((p) => seleccionados.contains(p.id))
                        .toList();

                    int addedProducts = 0;

                    for (var producto in productosMarcados) {
                      final existe = compraProvider.compras
                          .any((c) => c.idProducto == producto.id);

                      if (!existe) {
                        await compraProvider.agregarACompra(
                          producto.id!,
                          producto.precio,
                          producto.nombre,
                          producto.supermercado,
                        );
                        addedProducts++;
                      }
                    }

                    Navigator.pop(context);

                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message: addedProducts > 0
                          ? AppLocalizations.of(context)!.products_added_to_list
                          : AppLocalizations.of(context)!.products_already_in_list,
                      contentType: asc.ContentType.success,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Muestra una ventana con los detalles de un producto.
  void mostrarDetalleProducto(
      BuildContext context, Map<String, dynamic> producto) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (producto['foto'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        producto['foto'],
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    producto['nombre'] ?? '',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    producto['descripcion'] ??
                        AppLocalizations.of(context)!.no_description,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${AppLocalizations.of(context)!.price}: ${producto['precio']?.toStringAsFixed(2) ?? '-'} €',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppLocalizations.of(context)!.supermarket}: ${producto['supermercado'] ?? '-'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.close),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Abre la galería para seleccionar una nueva foto y la guarda temporalmente.
  ///
  /// Flujo principal:
  /// - Abre la galería del dispositivo para elegir una imagen.
  /// - Si el usuario no selecciona nada, no hace nada más.
  /// - Si selecciona una imagen, la guarda en nuevaFotoFile.
  /// - Marca en el DetalleRecetaProvider que la foto ha sido cambiada.
  void dialogEditarFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final imagenSeleccionada = File(pickedFile.path);

    setState(() {
      nuevaFotoFile = imagenSeleccionada;
    });

    context.read<DetalleRecetaProvider>().setCambioFoto(true);
  }

  /// Actualiza en la base de datos el título y la descripción de un paso de la receta.
  ///
  /// Flujo principal:
  /// - Busca el paso en la tabla pasos_receta usando el id de la receta y el número de paso.
  /// - Si lo encuentra, actualiza el título y la descripción con los nuevos valores.
  /// - Si no se encuentra el paso, devuelve false.
  /// - Si la actualización se hace correctamente, devuelve true.
  /// - Si ocurre un error durante el proceso, lo muestra por consola y devuelve false.
  Future<bool> actualizarPasoBBDD(
    int recetaId,
    int numeroPaso,
    String nuevoTitulo,
    String nuevaDescripcion,
  ) async {
    try {
      final response =
          await Supabase.instance.client.from('pasos_receta').update({
        'titulo': nuevoTitulo,
        'descripcion': nuevaDescripcion,
      }).match({
        'receta_id': recetaId,
        'numero_paso': numeroPaso,
      }).select();

      if (response.isEmpty) {
        if (kDebugMode) {
          print("No se encontró el paso para actualizar");
        }
        return false;
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Error al actualizar el paso: $e");
      }
      return false;
    }
  }

  /// METODO PARA MOSTRAR UN TEXTO AZUL PARA INTRODUCIR EL PRIMER PASO DE UNA RECETA SI NO TIENE PASOS.
  Widget textoAzulClickeable() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: GestureDetector(
          onTap: () async {
            final pasosProvider = context.read<PasosRecetaProvider>();

            await pasosProvider.crearPaso("", "");
            context.read<DetalleRecetaProvider>().setEdicion(true);
          },
          child: Text(
            AppLocalizations.of(context)!.first_time_step,
            style: const TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );
  }

  /// Controla lo que ocurre al intentar salir de la pantalla de detalle de una receta.
  ///
  /// Flujo principal:
  /// - Comprueba si hay cambios en el nombre, la foto o los pasos.
  /// - Si no hay cambios, desactiva el modo edición y permite salir.
  /// - Si hay cambios, muestra un cuadro de diálogo con tres opciones:
  ///   - Cancelar: cierra el cuadro y sigue en la pantalla.
  ///   - Salir sin guardar: muestra un aviso, borra los cambios y sale.
  ///   - Guardar y salir: guarda los cambios y luego cierra la pantalla.
  /// - Devuelve true si se puede salir, o false si debe mantenerse en la vista.
  Future<bool> _onWillPop() async {
    final detalleProvider = context.read<DetalleRecetaProvider>();

    final hayCambios = detalleProvider.cambioNombre ||
        detalleProvider.cambioFoto ||
        detalleProvider.cambioPaso;

    if (!hayCambios) {
      context.read<DetalleRecetaProvider>().setEdicion(false);
      return true;
    }

    final opcion = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.save_changes),
        content: Text(AppLocalizations.of(context)!.changes_confirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancelar'),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'salir'),
            child: Text(AppLocalizations.of(context)!.no_save_exit),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'guardar'),
            child: Text(AppLocalizations.of(context)!.save_exit),
          ),
        ],
      ),
    );

    if (opcion == 'cancelar') return false;

    if (opcion == 'salir') {
      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.warning,
        message: AppLocalizations.of(context)!.data_not_saved,
        contentType: asc.ContentType.warning,
      );
      detalleProvider.resetCambios();
      return true;
    }

    if (opcion == 'guardar') {
      await guardarCambios(cerrarPantalla: true);
      return false;
    }

    return false;
  }

  /// Guarda los cambios realizados en la receta.
  ///
  /// Flujo principal:
  /// - Comprueba si se ha cambiado el nombre, la foto o los pasos de la receta.
  /// - Si cambió el nombre o la descripción, actualiza la receta en la base de datos y en pantalla.
  /// - Si cambió la foto, la sube a Supabase y actualiza la URL en la receta.
  /// - Si cambió algún paso, recorre todos los pasos y los actualiza uno por uno.
  /// - Marca que ya no hay cambios pendientes y muestra un mensaje de éxito.
  /// - Si ocurre un error, muestra un mensaje de error.
  /// - Si cerrarPantalla es true, cierra la vista al terminar.
  Future<void> guardarCambios({bool cerrarPantalla = false}) async {
    final detalleProvider = context.read<DetalleRecetaProvider>();
    final recetaProvider = context.read<RecetaProvider>();
    final pasosProvider = context.read<PasosRecetaProvider>();

    try {
      if (detalleProvider.cambioNombre) {
        final recetaLocal = receta.copyWith(
          nombre: capitalize(nombreController.text.trim()),
          descripcion: capitalize(descripcionController.text.trim()),
          foto: receta.foto,
        );

        await recetaProvider.actualizarReceta(recetaLocal);

        if (mounted) {
          setState(() {
            receta = recetaLocal;
            nombreController.text = recetaLocal.nombre;
          });
        }

        detalleProvider.setCambioNombre(false);
      }

      if (detalleProvider.cambioFoto && nuevaFotoFile != null) {
        final bytes = await nuevaFotoFile!.readAsBytes();
        final nombreArchivo =
            '${widget.receta.nombre}_${Random().nextInt(9999).toString().padLeft(4, '0')}';
        final path = 'recetas/${widget.receta.usuarioUuid}/$nombreArchivo.jpg';

        await Supabase.instance.client.storage.from('fotos').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );

        final nuevaFotoUrlFinal =
            Supabase.instance.client.storage.from('fotos').getPublicUrl(path);

        final recetaFinal = widget.receta.copyWith(foto: nuevaFotoUrlFinal);
        await recetaProvider.actualizarReceta(recetaFinal);

        detalleProvider.setCambioFoto(false);
      }

      if (detalleProvider.cambioPaso) {
        for (final paso in pasosProvider.pasos) {
          await pasosProvider.actualizarPaso(paso);
        }
        detalleProvider.setCambioPaso(false);
      }

      detalleProvider.setEdicion(false);

      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.success,
        message: AppLocalizations.of(context)!.recipe_updated_ok,
        contentType: asc.ContentType.success,
      );
    } catch (e) {
      debugPrint("Error en guardarCambios: $e");
      showAwesomeSnackBar(
        context,
        title: "Error",
        message: AppLocalizations.of(context)!.recipe_updated_error,
        contentType: asc.ContentType.failure,
      );
    }

    if (cerrarPantalla && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // ---------- APP BAR ----------
            SliverAppBar(
              pinned: true,
              centerTitle: true,
              expandedHeight: 260,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Padding(
                  padding: const EdgeInsets.only(top: 50, left: 16, right: 16),

                  // ---------- FOTO DE LA RECETA ----------
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: nuevaFotoFile != null
                        ? Image.file(
                            nuevaFotoFile!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.contain,
                          )
                        : (receta.foto.isNotEmpty
                            ? (receta.foto.startsWith("http")
                                ? Image.network(
                                    receta.foto,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.contain,
                                  )
                                : Image.file(
                                    File(receta.foto),
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.contain,
                                  ))
                            : Container(
                                width: double.infinity,
                                height: 200,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.image,
                                      size: 60, color: Colors.white70),
                                ),
                              )),
                  ),
                ),
              ),

              // ---------- TITLO DEL APP BAR ----------
              title: AnimatedCrossFade(
                duration: const Duration(milliseconds: 400),
                crossFadeState: editandoNombre
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  receta.nombre,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                secondChild: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: nombreController,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        nuevoNombre = value.trim();
                      });
                      final nombreOriginal = widget.receta.nombre.trim();
                      final nuevoValor = capitalize(value.trim());

                      context
                          .read<DetalleRecetaProvider>()
                          .setCambioNombre(nuevoValor != nombreOriginal);
                    },
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                // ---------- STEPPER PERSONALIZADO ----------
                delegate: SliverChildListDelegate([
                  Builder(builder: (context) {
                    final pasosProvider = context.watch<PasosRecetaProvider>();
                    final detalleProvider =
                        context.watch<DetalleRecetaProvider>();

                    if (pasosProvider.estaCargando) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (pasosProvider.pasos.isEmpty) {
                      if (detalleProvider.estaEditando) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          context
                              .read<DetalleRecetaProvider>()
                              .setEdicion(false);
                        });
                      }

                      return textoAzulClickeable();
                    }

                    return StepperPersonalizado(
                        pasosReceta: pasosProvider.pasos);
                  }),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('${AppLocalizations.of(context)!.products}:',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      InkWell(
                        onTap: () {
                          mostrarDialogoSeleccionProductos(context);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 20),
                            const Icon(Icons.link,
                                size: 18, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)!.link_products,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ---------- LISTA DE PRODUCTOS ASOCIADOS A LA RECETA ----------
                  Consumer<ProductosRecetaProvider>(
                    builder: (context, prov, _) {
                      if (prov.productos.isEmpty) {
                        return Text(
                            AppLocalizations.of(context)!.no_linked_products);
                      }
                      return Column(
                        children: prov.productos.map((producto) {
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade600, width: 0.8),
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                            ),
                            child: SizedBox(
                              height: 85,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Center(
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 8),
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
                                    title: Text(
                                      producto.nombre,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey),
                                    onTap: () => mostrarDetalleProducto(
                                        context, producto.toMap()),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  )
                ]),
              ),
            ),
          ],
        ),
        floatingActionButton: (!editandoNombre &&
                !context.watch<DetalleRecetaProvider>().estaEditando)
            ? SpeedDial(
                heroTag: 'fab-menu',
                animatedIcon: AnimatedIcons.menu_close,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                buttonSize: const Size(58, 58),
                children: [
                  // ---------- ICONO EDITAR PASOS ----------
                  SpeedDialChild(
                    child: const Icon(Icons.description),
                    label: AppLocalizations.of(context)!.edit_step,
                    onTap: () async {
                      final pasosProvider = context.read<PasosRecetaProvider>();

                      if (pasosProvider.pasos.isEmpty) {
                        await pasosProvider.crearPaso("", "");
                      }

                      context.read<DetalleRecetaProvider>().setEdicion(true);
                    },
                  ),

                  // ---------- ICONO EDITAR IMAGEN ----------
                  SpeedDialChild(
                    child: const Icon(Icons.image),
                    label: AppLocalizations.of(context)!.change_photo,
                    onTap: () {
                      dialogEditarFoto();
                    },
                  ),

                  // ---------- ICONO EDITAR NOMBRE ----------
                  SpeedDialChild(
                    child: const Icon(Icons.edit),
                    label: AppLocalizations.of(context)!.edit_name,
                    onTap: () {
                      setState(() {
                        editandoNombre = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _focusNode.requestFocus();
                        Future.delayed(const Duration(milliseconds: 1), () {
                          nombreController.selection = TextSelection.collapsed(
                            offset: nombreController.text.length,
                          );
                        });
                      });
                    },
                  ),
                ],
              )

            // ---------- FABS CONFIRMAR CAMBIOS / CANCELAR CAMBIOS ----------
            : Row(
                children: [
                  const Spacer(),
                  FloatingActionButton(
                    heroTag: 'fab-save',
                    onPressed: () async {
                      await guardarCambios();
                      context.read<DetalleRecetaProvider>().setEdicion(false);
                      setState(() {
                        editandoNombre = false;
                      });
                    },
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.check, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton(
                    heroTag: 'fab-cancel',
                    onPressed: () {
                      context.read<DetalleRecetaProvider>().setEdicion(false);
                      editandoNombre = false;
                      context
                          .read<DetalleRecetaProvider>()
                          .setCambioNombre(false);
                    },
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.cancel, color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }
}
