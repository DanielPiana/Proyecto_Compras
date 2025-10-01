import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/PasoReceta.dart';

class PasosRecetaProvider extends ChangeNotifier {
  final SupabaseClient database;
  final int recetaId;

  PasosRecetaProvider(this.database, this.recetaId);

  List<PasoReceta> _pasos = [];
  List<PasoReceta> get pasos => _pasos;

  bool _estaCargando = false;
  bool get estaCargando => _estaCargando;

  Future<void> cargarPasos() async {
    _estaCargando = true;
    notifyListeners();

    try {
      final data = await database
          .from('pasos_receta')
          .select()
          .eq('receta_id', recetaId)
          .order('numero_paso', ascending: true);

      _pasos = data.map<PasoReceta>(
            (map) => PasoReceta.fromJson(map, map['numero_paso']),
      ).toList();
    } catch (e) {
      print("❌ Error al cargar pasos: $e");
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }

  void actualizarPasoLocal(int numeroPaso, PasoReceta pasoActualizado) {
    final index = _pasos.indexWhere((p) => p.numeroPaso == numeroPaso);
    if (index != -1) {
      _pasos[index] = pasoActualizado;
      notifyListeners();
    }
  }

  Future<void> crearPaso(String titulo, String descripcion) async {
    //CALCULAMOS EL NUEVO NUMERO DE PASO LOCALMENTE
    final nuevoNumeroPaso = _pasos.isEmpty ? 1 : _pasos.last.numeroPaso + 1;

    final nuevoPaso = PasoReceta(
      numeroPaso: nuevoNumeroPaso,
      titulo: titulo.trim(),
      descripcion: descripcion.trim(),
    );
    _pasos.add(nuevoPaso);
    notifyListeners();
    try {
      await database.from('pasos_receta').insert(nuevoPaso.toMap(recetaId: recetaId));
    } catch (e) {
      print("❌ Error al crear paso: $e");
      _pasos.removeWhere((p) => p.numeroPaso == nuevoNumeroPaso);
      notifyListeners();
    }
  }

  Future<void> actualizarPaso(PasoReceta paso) async {
    final index = _pasos.indexWhere((p) => p.numeroPaso == paso.numeroPaso);
    if (index != -1) {
      _pasos[index] = paso;
      notifyListeners();
    }

    try {
      await database
          .from('pasos_receta')
          .update(paso.toMap(recetaId: recetaId))
          .match({
        'receta_id': recetaId,
        'numero_paso': paso.numeroPaso,
      });
    } catch (e) {
      print("❌ Error al actualizar paso: $e");
    }
  }

  Future<void> eliminarPaso(int numeroPaso) async {
    final eliminado = _pasos.firstWhere((p) => p.numeroPaso == numeroPaso);
    _pasos.removeWhere((p) => p.numeroPaso == numeroPaso);
    notifyListeners();

    try {
      await database
          .from('pasos_receta')
          .delete()
          .match({
        'receta_id': recetaId,
        'numero_paso': numeroPaso,
      });

      print("✅ Paso $numeroPaso eliminado en Supabase");
    } catch (e) {
      print("❌ Error al eliminar paso: $e");
      _pasos.add(eliminado);
      _pasos.sort((a, b) => a.numeroPaso.compareTo(b.numeroPaso));
      notifyListeners();
    }
  }

}
