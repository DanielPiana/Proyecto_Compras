import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/detalleRecetaProvider.dart';
import 'package:proyectocompras/utils/capitalize.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  Future<List<Map<String, dynamic>>> obtenerProductos() async {
    final res = await Supabase.instance.client.from('productos').select();
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> guardarProductosEnReceta(int recetaId, Set<int> nuevosSeleccionados) async {
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
              TextButton(
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
          ),
        );
      },
    );
  }

  void mostrarDetalleProducto(BuildContext context, Map<String, dynamic> producto) {
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

  void dialogEditarNombre() {
    final controller = TextEditingController(text: receta.nombre);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.edit_name),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.new_name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                nuevoNombre = controller.text.trim();
              });
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }

  Future<bool> actualizarPasoBBDD(int recetaId, int numeroPaso, String nuevoTitulo, String nuevaDescripcion,) async {
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
        print("⚠️ No se encontró el paso para actualizar");
        return false;
      }

      print("✅ Paso actualizado correctamente: $response");
      return true;
    } catch (e) {
      print("❌ Error al actualizar el paso: $e");
      return false;
    }
  }

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
      debugPrint("❌ Error en guardarCambios: $e");
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
            SliverAppBar(
              pinned: true,
              centerTitle: true,
              expandedHeight: 260,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Padding(
                  padding: const EdgeInsets.only(top: 50, left: 16, right: 16),
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
              title: AnimatedCrossFade(
                duration: const Duration(milliseconds: 400),
                crossFadeState: editandoNombre
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  receta.nombre,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold
                  ),
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

                      context.read<DetalleRecetaProvider>().setCambioNombre(
                          nuevoValor != nombreOriginal
                      );
                    },
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
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
                  Consumer<ProductosRecetaProvider>(
                    builder: (context, prov, _) {
                      if (prov.productos.isEmpty) {
                        return Text(AppLocalizations.of(context)!.no_linked_products);
                      }

                      return Column(
                        children: prov.productos.map((producto) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade600, width: 0.8),
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                            ),
                            child: SizedBox(
                              height: 85,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Center(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: AspectRatio(
                                        aspectRatio: 1.4,
                                        child: producto.foto.isNotEmpty
                                            ? Image.network(
                                          producto.foto,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image_not_supported,
                                              size: 50, color: Colors.grey),
                                        )
                                            : const Icon(Icons.image_not_supported,
                                            size: 50, color: Colors.grey),
                                      ),
                                    ),
                                    title: Text(
                                      producto.nombre,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios,
                                        size: 16, color: Colors.grey),
                                    onTap: () => mostrarDetalleProducto(context, producto.toMap()),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          buttonSize: const Size(58, 58),
          children: [
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
            SpeedDialChild(
              child: const Icon(Icons.image),
              label: AppLocalizations.of(context)!.change_photo,
              onTap: () {
                dialogEditarFoto();
              },
            ),
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
            : Row(
          children: [
            const Spacer(),
            FloatingActionButton(
              heroTag: 'fab-save',
              onPressed: () async {
                await guardarCambios();
                context.read<DetalleRecetaProvider>().setEdicion(false);
                setState(() {editandoNombre = false;
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
