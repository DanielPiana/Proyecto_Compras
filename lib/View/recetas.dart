import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/productosRecetaProvider.dart';
import 'package:proyectocompras/utils/capitalize.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/pasosRecetaProvider.dart';
import '../Providers/recetaProvider.dart';
import '../Providers/userProvider.dart';
import 'package:flutter/foundation.dart';
import '../Widgets/awesomeSnackbar.dart';
import '../l10n/app_localizations.dart';
import '../models/recetaModel.dart';
import 'detalleReceta.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;

class Recetas extends StatefulWidget {
  const Recetas({super.key});

  @override
  State<Recetas> createState() => RecetasState();
}

class RecetasState extends State<Recetas> {
  int indiceRecetaActual = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> mostrarDialogoCrearReceta(BuildContext context, int indiceRecetaActual) async {

    final TextEditingController nombreController = TextEditingController();
    final TextEditingController descripcionController = TextEditingController();
    File? imagenSeleccionada;
    String? tiempoSeleccionado;

    bool nombreValido = false;
    bool descripcionValida = false;
    bool tiempoValido = false;

    bool nombreTouched = false;
    bool descripcionTouched = false;
    bool tiempoTouched = false;

    List<String> tiempos(BuildContext context) => [
      AppLocalizations.of(context)!.lessThan15,
      AppLocalizations.of(context)!.lessThan30,
      AppLocalizations.of(context)!.lessThan45,
      AppLocalizations.of(context)!.lessThan1h,
      AppLocalizations.of(context)!.lessThan1h30,
      AppLocalizations.of(context)!.lessThan2h,
      AppLocalizations.of(context)!.moreThan2h,
    ];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.new_recipe),
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
                          ? const Icon(Icons.check_circle, color: Colors.green)
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
                    Text(
                      AppLocalizations.of(context)!.name_error_message,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descripcionController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.description,
                      suffixIcon: descripcionTouched
                          ? (descripcionValida
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.cancel, color: Colors.red))
                          : null,
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      setState(() {
                        descripcionTouched = true;
                        descripcionValida = value.trim().isNotEmpty;
                      });
                    },
                  ),
                  if (descripcionTouched && !descripcionValida)
                    Text(
                      AppLocalizations.of(context)!.description_error_message,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: tiempoSeleccionado,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.estimated_time,
                      suffixIcon: tiempoTouched
                          ? (tiempoValido
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.cancel, color: Colors.red))
                          : null,
                    ),
                    items: tiempos(context).map((tiempo) {
                      return DropdownMenuItem(
                        value: tiempo,
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
                            Text(tiempo, style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      );
                    }).toList(),
                    selectedItemBuilder: (context) {
                      return tiempos(context).map((s) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child:
                          Text(s, style: const TextStyle(fontSize: 16)),
                        );
                      }).toList();
                    },
                    onChanged: (valor) {
                      setState(() {
                        tiempoTouched = true;
                        tiempoSeleccionado = valor;
                        tiempoValido = valor != null && valor.trim().isNotEmpty;
                      });
                    },
                  ),
                  if (tiempoTouched && !tiempoValido)
                    Text(
                      AppLocalizations.of(context)!.time_error_message,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: Text(AppLocalizations.of(context)!.select_photo),
                      onPressed: () async {
                        File? imagen;

                        if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
                          final picker = ImagePicker();
                          final pickedFile =
                          await picker.pickImage(source: ImageSource.gallery);
                          if (pickedFile != null) {
                            imagen = File(pickedFile.path);
                          }
                        } else {
                          final result = await FilePicker.platform
                              .pickFiles(type: FileType.image);
                          if (result != null && result.files.single.path != null) {
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
            actions: [
              ElevatedButton(
                child: Text(AppLocalizations.of(context)!.cancel),
                onPressed: () => Navigator.pop(dialogContext),
              ),
              ElevatedButton(
                child: Text(AppLocalizations.of(context)!.save),
                onPressed: () async {
                  setState(() {
                    nombreTouched = true;
                    descripcionTouched = true;
                    tiempoTouched = true;

                    nombreValido = nombreController.text.trim().isNotEmpty;
                    descripcionValida = descripcionController.text.trim().isNotEmpty;
                    tiempoValido = tiempoSeleccionado != null &&
                        tiempoSeleccionado!.trim().isNotEmpty;
                  });

                  if (!nombreValido || !descripcionValida || !tiempoValido) {
                    return;
                  }

                  final nombre = capitalize(nombreController.text.trim());
                  final descripcion = capitalize(descripcionController.text.trim());
                  final uuidUsuario = context.read<UserProvider>().uuid;

                  if (nombre.isEmpty || uuidUsuario == null) return;

                  try {
                    String? urlImagen;

                    if (imagenSeleccionada != null) {
                      final bytes = await imagenSeleccionada!.readAsBytes();
                      final nombreArchivo =
                          '${nombre}_${Random().nextInt(9999).toString().padLeft(4, '0')}';
                      final path = 'recetas/$uuidUsuario/$nombreArchivo.jpg';

                      await Supabase.instance.client.storage
                          .from('fotos')
                          .uploadBinary(path, bytes,
                          fileOptions:
                          const FileOptions(contentType: 'image/jpeg'));

                      urlImagen = Supabase.instance.client.storage
                          .from('fotos')
                          .getPublicUrl(path);
                    }

                    final nuevaReceta = RecetaModel(
                      nombre: nombre,
                      descripcion: descripcion,
                      usuarioUuid: uuidUsuario,
                      foto: urlImagen ?? '',
                      tiempo: tiempoSeleccionado ?? '',
                    );

                    await context.read<RecetaProvider>().crearReceta(nuevaReceta);

                    Navigator.pop(dialogContext);
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message: AppLocalizations.of(context)!.recipe_created_ok,
                      contentType: asc.ContentType.success,
                    );
                  } catch (e) {
                    showAwesomeSnackBar(
                      context,
                      title: 'Error',
                      message: AppLocalizations.of(context)!.recipe_created_error,
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


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecetaProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.recipes,
          style: const TextStyle(
              fontSize: 30,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: botón de compartir
            },
          ),
        ],
      ),
      body: provider.recetas.isEmpty
          ? const Center(
        child: (CircularProgressIndicator()),
      )
          : LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          int crossAxisCount = 1;

          if (width >= 1200) {
            crossAxisCount = 5;
          } else if (width >= 900) {
            crossAxisCount = 4;
          } else if (width >= 600) {
            crossAxisCount = 2;
          }

          return GridView.builder(
            itemCount: provider.recetas.length,
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: 280,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final receta = provider.recetas[index];
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                        color: Colors.grey.shade600,
                        width: 0.8
                    )
                ),
                elevation: 4,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final resultado = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MultiProvider(
                          providers: [
                            ChangeNotifierProvider(
                              create: (_) => PasosRecetaProvider(
                                Supabase.instance.client,
                                receta.id!,
                              )..cargarPasos(),
                            ),
                            ChangeNotifierProvider(
                              create: (_) => ProductosRecetaProvider(
                                Supabase.instance.client,
                                receta.id!,
                              )..cargarProductos(),
                            ),
                          ],
                          child: DetalleReceta(receta: receta),
                        ),
                      ),
                    );
                    if (resultado == true) {
                      provider.cargarRecetas();
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade600,
                            width: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          child: Stack(
                            children: [
                              receta.foto.isNotEmpty
                                  ? Image.network(
                                receta.foto,
                                width: double.infinity,
                                height: 150,
                                fit: BoxFit.contain,
                              )
                                  : Container(
                                width: double.infinity,
                                height: 150,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'compartir') {
                                        // TODO: método compartir
                                      } else if (value == 'eliminar') {
                                        try {
                                          await provider
                                              .eliminarReceta(receta.id!);

                                          showAwesomeSnackBar(
                                            context,
                                            title: AppLocalizations.of(
                                                context)!
                                                .success,
                                            message: AppLocalizations.of(
                                                context)!
                                                .recipe_deleted_ok,
                                            contentType:
                                            asc.ContentType.success,
                                          );
                                        } catch (e) {
                                          showAwesomeSnackBar(
                                            context,
                                            title: 'Error',
                                            message: AppLocalizations.of(
                                                context)!
                                                .recipe_deleted_error,
                                            contentType:
                                            asc.ContentType.failure,
                                          );
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'compartir',
                                        child: Text(
                                            AppLocalizations.of(context)!
                                                .share),
                                      ),
                                      PopupMenuItem(
                                        value: 'eliminar',
                                        child: Text(
                                            AppLocalizations.of(context)!
                                                .delete),
                                      ),
                                    ],
                                    icon: const Icon(Icons.more_vert,
                                        color: Colors.white, size: 20),
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              receta.nombre,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${AppLocalizations.of(context)!.time}: ${receta.tiempo}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          mostrarDialogoCrearReceta(context, indiceRecetaActual);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
