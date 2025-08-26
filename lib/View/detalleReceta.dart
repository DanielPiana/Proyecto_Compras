import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/detalleRecetaProvider.dart';
import 'package:proyectocompras/Widgets/crearPasosReceta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Widgets/stepperPersonalizado.dart';
import '../models/PasoReceta.dart';
import '../Providers/userProvider.dart';

class DetalleReceta extends StatefulWidget {
  final Map<String, dynamic> receta;

  const DetalleReceta({super.key, required this.receta});

  @override
  State<DetalleReceta> createState() => _DetalleRecetaState();
}

class _DetalleRecetaState extends State<DetalleReceta> {
  late Map<String, dynamic> receta;

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
  bool primerPaso = false;
  bool estaCargandoPasos = true;

  @override
  void initState() {
    super.initState();
    receta = Map<String, dynamic>.from(widget.receta);
    nombreController.text = receta['nombre'];
    cargarPasos();
  }

  Future<List<PasoReceta>> obtenerPasosPorReceta(int recetaId) async {
    final supabase = Supabase.instance.client;
    final datos = await supabase
        .from('pasos_receta')
        .select('titulo, descripcion, numero_paso')
        .eq('receta_id', recetaId)
        .order('numero_paso', ascending: true);

    return datos.asMap().entries.map((entry) {
      final index = entry.key;
      final fila = entry.value;
      return PasoReceta.fromJson(fila, fila['numero_paso']);
    }).toList();
  }

  void cargarPasos() async {
    final nuevosPasos = await obtenerPasosPorReceta(receta['id']);
    setState(() {
      pasos = nuevosPasos;
      estaCargandoPasos = false;
    });
  }

  Future<List<Map<String, dynamic>>> cargarProductosAsociados(
      int recetaId) async {
    final res = await Supabase.instance.client
        .from('receta_producto')
        .select(
            'productos(id, nombre, descripcion, precio, foto, supermercado)')
        .eq('idreceta', recetaId);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> obtenerProductos() async {
    final res = await Supabase.instance.client.from('productos').select();
    return List<Map<String, dynamic>>.from(res);
  }

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

  void mostrarDialogoSeleccionProductos(BuildContext context) async {
    final productosDisponibles = await obtenerProductos();

    final asociadosRaw = await Supabase.instance.client
        .from('receta_producto')
        .select('idproducto')
        .eq('idreceta', receta['id']);

    final Set<int> seleccionados =
        Set<int>.from(asociadosRaw.map((r) => r['idproducto'] as int));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Selecciona productos'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: productosDisponibles.length,
                itemBuilder: (_, index) {
                  final producto = productosDisponibles[index];
                  final id = producto['id'];

                  return CheckboxListTile(
                    value: seleccionados.contains(id),
                    title: Text(producto['nombre']),
                    onChanged: (bool? checked) {
                      setStateDialog(() {
                        if (checked == true) {
                          seleccionados.add(id);
                        } else {
                          seleccionados.remove(id);
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
                  child: const Text('Cancelar')),
              ElevatedButton(
                child: const Text('Guardar'),
                onPressed: () async {
                  await guardarProductosEnReceta(receta['id'], seleccionados);
                  Navigator.pop(context);
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
                    producto['descripcion'] ?? 'Sin descripción',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Precio: ${producto['precio']?.toStringAsFixed(2) ?? '-'} €',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supermercado: ${producto['supermercado'] ?? '-'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void dialogEditarFoto(int recetaId, String nombreReceta, String uuidUsuario) async {
    File? imagenSeleccionada;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      imagenSeleccionada = File(pickedFile.path);
    }

    if (imagenSeleccionada == null) return;

    final bytes = await imagenSeleccionada.readAsBytes();
    final nombreArchivo =
        '${nombreReceta}_${Random().nextInt(9999).toString().padLeft(4, '0')}';
    final path = 'recetas/$uuidUsuario/$nombreArchivo.jpg';

    await Supabase.instance.client.storage.from('fotos').uploadBinary(
        path, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'));

    final urlImagen =
        Supabase.instance.client.storage.from('fotos').getPublicUrl(path);

    setState(() {
      receta['foto'] = urlImagen;
      nuevaFotoUrl = urlImagen;
    });
  }

  Future<void> actualizarFotoBBDD(int recetaId, String nuevaFoto) async {
    await Supabase.instance.client
        .from('recetas')
        .update({'foto': nuevaFoto}).eq('id', recetaId);
  }

  void dialogEditarNombre() {
    final controller = TextEditingController(text: receta['nombre']);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar nombre'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nuevo nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                nuevoNombre = controller.text.trim();
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> actualizarNombreBBDD(int recetaId, String nuevoNombre) async {
    await Supabase.instance.client
        .from('recetas')
        .update({'nombre': nuevoNombre}).eq('id', recetaId);
  }

  Future<bool> actualizarPasoBBDD(
      int recetaId,
      int numeroPaso,
      String nuevoTitulo,
      String nuevaDescripcion,
      ) async {

    print(recetaId);
    print(numeroPaso);
    print(nuevoTitulo);
    print(nuevaDescripcion);
    try {
      final response = await Supabase.instance.client
          .from('pasos_receta')
          .update({
        'titulo': nuevoTitulo,
        'descripcion': nuevaDescripcion,
      })
          .match({
        'receta_id': recetaId,
        'numero_paso': numeroPaso,
      })
          .select(); // 👈 esto hace que te devuelva las filas actualizadas

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



  Future<bool> _onWillPop() async {

    nuevoTituloPaso = context.read<DetalleRecetaProvider>().nuevoTituloPaso;
    nuevaDescripcionPaso = context.read<DetalleRecetaProvider>().nuevaDescripcionPaso;
    pasoActualizar = context.read<DetalleRecetaProvider>().pasoActualParaActualizar;
    pasoActualizar = context.read<DetalleRecetaProvider>().pasoActualParaActualizar;
    cambios = context.read<DetalleRecetaProvider>().hayCambiosProvider;

    // nuevaFotoUrl para la foto
    // nuevoNombre para el nombre de la receta
    // tituloController para el titulo del primer paso de una receta
    // descripcionController para la descripcion de una primera receta

    // nuevoTituloPaso para el titulo del paso
    // nuevaDescripcionPaso para la descripcion del paso


    final hayCambios = nuevaFotoUrl.isNotEmpty ||
        nuevoNombre.isNotEmpty ||
        nuevaDescripcionPaso.isNotEmpty ||
        nuevoTituloPaso.isNotEmpty ||
        tituloController.text.isNotEmpty ||
        descripcionController.text.isNotEmpty;

    try {
      if (!hayCambios) return true;

      final opcion = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Guardar cambios?'),
          content: const Text('Tienes cambios sin guardar. ¿Qué deseas hacer?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancelar'),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'salir'),
              child: const Text('Salir sin guardar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'guardar'),
              child: const Text('Guardar y salir'),
            ),
          ],
        ),
      );

      if (opcion == 'cancelar') {
        return false;
      } else if (opcion == 'salir') {
        return true;
      } else if (opcion == 'guardar') {
        if (nuevaFotoUrl.isNotEmpty) {
          await actualizarFotoBBDD(receta['id'], nuevaFotoUrl);
        }
        if (nuevoNombre.isNotEmpty) {
          await actualizarNombreBBDD(receta['id'], nuevoNombre);
        }
        if (cambios) {
          actualizarPasoBBDD(receta['id'], pasoActualizar, nuevoTituloPaso, nuevaDescripcionPaso);
        }
        if (tituloController.text.isNotEmpty &&
            descripcionController.text.isNotEmpty) {
          await CrearPasosRecetaState.actualizarPasoBBDD(
              receta['id'], tituloController.text, descripcionController.text);
        }
        Navigator.pop(context, true);
        return false;
      }

      return false;
    } finally {
      // Esto se ejecuta siempre, pase lo que pase
      context.read<DetalleRecetaProvider>().cambioEstadoEdicion(false);
    }
  }

  Widget textoAzulClickeable() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: GestureDetector(
          onTap: () => setState(() {
            primerPaso = true;
            pasos.add(PasoReceta(titulo: '', descripcion: '', numeroPaso: 1));
          }),
          child: const Text(
            'Para añadir tu primer paso haz click aquí',
            style: TextStyle(
                fontSize: 16, fontStyle: FontStyle.italic, color: Colors.blue),
          ),
        ),
      ),
    );
  }

  Future<void> mostrarDialogoConfirmarCambios(BuildContext context) async {
    final provider = context.read<DetalleRecetaProvider>();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cambios'),
        content: const Text('¿Seguro que quieres confirmar los cambios realizados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (resultado == true) {
      if (provider.hayCambiosProvider) {
        await actualizarPasoBBDD(
          receta['id'],
          pasoActualizar,
          provider.nuevoTituloPaso,
          provider.nuevaDescripcionPaso,
        );
      }

      if (nuevoNombre.isNotEmpty) {
        await actualizarNombreBBDD(receta['id'], nuevoNombre);
      }

      provider.cambioEstadoEdicion(false);
      provider.setNuevoTitulo('');
      provider.setNuevaDescripcion('');

      setState(() {
        editandoNombre = false;
        nuevoNombre = '';
      });

      // TODO
      // RECARGAR EL CONTENIDO CON UN PROVIDER
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
                  padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: receta['foto'] != null
                        ? Image.network(
                            receta['foto'],
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.image,
                                  size: 60, color: Colors.white70),
                            ),
                          ),
                  ),
                ),
              ),
              title: AnimatedCrossFade(
                duration: const Duration(milliseconds: 400),
                crossFadeState: editandoNombre
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  receta['nombre'],
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                secondChild: TextField(
                  controller: nombreController,
                  focusNode: _focusNode,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      nuevoNombre = value.trim();
                    });
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  (pasos.isEmpty && !primerPaso)
                      ? textoAzulClickeable()
                      : (pasos.isNotEmpty && !primerPaso)
                          ? StepperPersonalizado(
                              pasosReceta: pasos,
                            )
                          : CrearPasosReceta(
                              recetaId: receta['id'],
                              onPasoGuardado: (nuevoPaso) {
                                setState(() {
                                  pasos.add(nuevoPaso);
                                  primerPaso = false;
                                });
                              },
                            ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text('Productos:',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                          onPressed: () {
                            mostrarDialogoSeleccionProductos(context);
                          },
                          icon: const Icon(Icons.link),
                          label: const Text('Añadir productos')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: cargarProductosAsociados(receta['id']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('No hay productos asociados');
                      }
                      final productos = snapshot.data!;
                      return Column(
                        children: List.generate(
                          productos.length,
                          (index) {
                            final producto = productos[index]['productos'];
                            return GestureDetector(
                              onTap: () =>
                                  mostrarDetalleProducto(context, producto),
                              child: Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      if (producto['foto'] != null)
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            producto['foto'],
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      else
                                        const Icon(Icons.image_not_supported,
                                            size: 60),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          producto['nombre'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios,
                                          size: 16, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
        floatingActionButton: (!editandoNombre && !context.watch<DetalleRecetaProvider>().estaEditando) ? SpeedDial(
          animatedIcon: AnimatedIcons.menu_close,
          backgroundColor: Colors.deepOrange,
          overlayOpacity: 0.3,
          children: [
            SpeedDialChild(
              child: const Icon(Icons.edit),
              label: 'Editar nombre',
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
            SpeedDialChild(
              child: const Icon(Icons.image),
              label: 'Cambiar foto',
              onTap: () {
                dialogEditarFoto(
                  receta['id'],
                  receta['nombre'],
                  context.read<UserProvider>().uuid.toString(),
                );
              },
            ),
            SpeedDialChild(
              child: const Icon(Icons.description),
              label: 'Editar paso',
              onTap: () {
                context.read<DetalleRecetaProvider>().cambioEstadoEdicion(true);
              },
            ),
          ],
        ): Row(
          children: [
            const Spacer(),
            FloatingActionButton(
              onPressed: () {
                mostrarDialogoConfirmarCambios(context);
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.check, color: Colors.white),
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              onPressed: () {
                context.read<DetalleRecetaProvider>().setEdicion(false);
                editandoNombre = false;
              },
              backgroundColor: Colors.red,
              child: const Icon(Icons.cancel, color: Colors.white),
            ),
          ],
        )

        ,
      ),
    );
  }
}
