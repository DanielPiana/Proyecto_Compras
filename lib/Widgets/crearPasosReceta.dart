import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/PasoReceta.dart';

class CrearPasosReceta extends StatefulWidget {
  final int recetaId;
  final Function(PasoReceta) onPasoGuardado;

  const CrearPasosReceta({
    super.key,
    required this.recetaId,
    required this.onPasoGuardado,
  });

  @override
  State<CrearPasosReceta> createState() => CrearPasosRecetaState();

}

class CrearPasosRecetaState extends State<CrearPasosReceta> {
  final tituloController = TextEditingController();
  final descripcionController = TextEditingController();

  @override
  void dispose() {
    tituloController.dispose();
    descripcionController.dispose();
    super.dispose();
  }

  static Future<PasoReceta?> guardarPasoBBDD(int recetaId, String titulo, String descripcion) async {
    final supabase = Supabase.instance.client;

    try {
      // Obtener el número de paso más alto
      final response = await supabase
          .from('pasos_receta')
          .select('numero_paso')
          .eq('receta_id', recetaId)
          .order('numero_paso', ascending: false)
          .limit(1);

      int nuevoNumeroPaso = 1;
      if (response.isNotEmpty) {
        nuevoNumeroPaso = (response.first['numero_paso'] as int) + 1;
      }

      // Insertar el nuevo paso en Supabase
      await supabase.from('pasos_receta').insert({
        'receta_id': recetaId,
        'numero_paso': nuevoNumeroPaso,
        'titulo': titulo.trim(),
        'descripcion': descripcion.trim(),
      });

      // Crear un objeto PasoReceta para devolver
      return PasoReceta(
        titulo: titulo.trim(),
        descripcion: descripcion.trim(),
        numeroPaso: nuevoNumeroPaso,
      );
    } catch (e) {
      print('Error al guardar el paso: $e');
      return null; // O puedes lanzar una excepción personalizada
    }
  }

  Future<void> guardarPaso() async {
    final titulo = tituloController.text.trim();
    final descripcion = descripcionController.text.trim();

    if (titulo.isEmpty || descripcion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    final nuevoPaso = await guardarPasoBBDD(widget.recetaId, titulo, descripcion);
    if (nuevoPaso != null) {
      widget.onPasoGuardado(nuevoPaso);
      tituloController.clear();
      descripcionController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar el paso')),
      );
    }
  }

  static Future<void> actualizarPasoBBDD(int recetaId,String titulo, String descripcion) async {

  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: tituloController,
            decoration: const InputDecoration(
              labelText: 'Título del paso',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: double.infinity),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: TextField(
                  controller: descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción del paso',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: guardarPaso,
              child: const Text('Guardar paso'),
            ),
          ),
        ],
      ),
    );
  }
}
