import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/userProvider.dart';
import 'package:flutter/foundation.dart';

import 'detalleReceta.dart';



class Recetas extends StatefulWidget {
  const Recetas({super.key});

  @override
  State<Recetas> createState() => RecetasState();
}

class RecetasState extends State<Recetas> {
  SupabaseClient database = Supabase.instance.client;

  List<dynamic> listaRecetas = [];

  int indiceRecetaActual = 0;

  @override
  void initState() {
    super.initState();
    cargarRecetas();
  }

  Future<void> cargarRecetas() async {
    try {
      final uuid = context
          .read<UserProvider>()
          .uuid!;
      final response = await database
          .from('recetas')
          .select()
          .eq('usuariouuid', uuid)
          .order('id', ascending: false);
      if (mounted) {
        setState(() {
          listaRecetas = response as List<dynamic>;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar recetas: $e');
    }
  }

  Future<void> mostrarDialogoCrearReceta(BuildContext context, int indiceRecetaActual) async {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController descripcionController = TextEditingController();
    File? imagenSeleccionada;
    String? tiempoSeleccionado;

    final tiempos = [
      'Menos de 15 minutos',
      'Menos de 30 minutos',
      'Menos de 45 minutos',
      'Menos de 1 hora',
      'Menos de 1hora y 30 minutos',
      'Menos de 2 horas',
      'Más de 2 horas'
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) =>
              AlertDialog(
                title: const Text('Nueva Receta'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                      TextField(
                        controller: descripcionController,
                        decoration: const InputDecoration(
                            labelText: 'Descripción'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tiempoSeleccionado,
                        decoration: const InputDecoration(
                            labelText: 'Tiempo estimado'),
                        items: tiempos.map((tiempo) {
                          return DropdownMenuItem(
                            value: tiempo,
                            child: Text(tiempo),
                          );
                        }).toList(),
                        onChanged: (valor) {
                          setState(() {
                            tiempoSeleccionado = valor;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text('Seleccionar imagen'),
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
                            final result = await FilePicker.platform.pickFiles(
                                type: FileType.image);
                            if (result != null && result.files.single.path !=
                                null) {
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
                      const SizedBox(height: 8),
                      if (imagenSeleccionada != null)
                        Image.file(imagenSeleccionada!, height: 100,
                            fit: BoxFit.cover),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancelar'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  ElevatedButton(
                    child: const Text('Guardar'),
                    onPressed: () async {
                      final nombre = nombreController.text.trim();
                      final descripcion = descripcionController.text.trim();
                      final uuidUsuario = context.read<UserProvider>().uuid;

                      if (nombre.isEmpty || uuidUsuario == null) return;

                      String? urlImagen;

                      if (imagenSeleccionada != null) {
                        final bytes = await imagenSeleccionada!.readAsBytes();
                        final recetaActual = listaRecetas[indiceRecetaActual];
                        final nombreArchivo = '${recetaActual['nombre']}_${Random()
                            .nextInt(9999).toString()
                            .padLeft(4, '0')}';
                        final path = 'recetas/$uuidUsuario/$nombreArchivo.jpg';

                        await Supabase.instance.client.storage
                            .from('fotos')
                            .uploadBinary(path, bytes,
                            fileOptions: const FileOptions(
                                contentType: 'image/jpeg'));

                        urlImagen = Supabase.instance.client.storage
                            .from('fotos')
                            .getPublicUrl(path);
                      }

                      // Insertamos en la tabla
                      await Supabase.instance.client.from('recetas').insert({
                        'usuariouuid': uuidUsuario,
                        'nombre': nombre,
                        'descripcion': descripcion,
                        'tiempo': tiempoSeleccionado,
                        'foto': urlImagen,
                      });
                      cargarRecetas();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
        );
      },
    );
  }

  Future<void> eliminarReceta(BuildContext context, int id) async {
    await Supabase.instance.client
        .from('recetas')
        .delete()
        .eq('id', id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Receta eliminada correctamente'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
    cargarRecetas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Recetas')),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: botón de compartir
            },
          ),
        ],
      ),
      body: listaRecetas.isEmpty
          ? const Center(
        child:(CircularProgressIndicator()),
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
            itemCount: listaRecetas.length,
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: 280,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final receta = listaRecetas[index];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final resultado = await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => DetalleReceta(receta:receta)
                      ),
                    );
                    if (resultado == true) {
                      cargarRecetas();
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Stack(
                          children: [
                            receta['foto'] != null
                                ? Image.network(
                              receta['foto'],
                              width: double.infinity,
                              height: 150,
                              fit: BoxFit.cover,
                            )
                                : Container(
                              width: double.infinity,
                              height: 150,
                              color: Colors.grey[300],
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
                                  onSelected: (value) {
                                    if (value == 'compartir') {
                                      // Acción para compartir
                                    } else if (value == 'eliminar') {
                                      eliminarReceta(context,receta['id']);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'compartir',
                                      child: Text('Compartir'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'eliminar',
                                      child: Text('Eliminar'),
                                    ),
                                  ],
                                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                                  color: Colors.white,
                                ),
                              ),
                            ),

                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              receta['nombre'],
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tiempo: ${receta['tiempo'] ?? 'N/A'}',
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
