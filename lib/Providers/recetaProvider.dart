import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recetaModel.dart';

class RecetaProvider with ChangeNotifier {
  final SupabaseClient database;
  String? userId;

  RecetaProvider(this.database, this.userId);

  List<RecetaModel> _recetas = [];

  List<RecetaModel> get recetas => _recetas;

  Future<void> setUserAndReload(String? uuid) async {
    userId = uuid;
    if (uuid == null) {
      _recetas = [];
      notifyListeners();
      return;
    }
    await cargarRecetas();
  }

  Future<void> cargarRecetas() async {
    try {
      final data = await database
          .from('recetas')
          .select()
          .eq('usuariouuid', userId!)
          .order('id', ascending: false);

      _recetas = data.map<RecetaModel>((r) => RecetaModel.fromMap(r)).toList();
      ordenarRecetas(_recetas);
      notifyListeners();
    } catch (e) {
      debugPrint("Error al cargar recetas: $e");
    }
  }

  List<RecetaModel> ordenarRecetas(List<RecetaModel> recetas) {
    recetas.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return recetas;
  }

  Future<void> crearReceta(RecetaModel nuevaReceta) async {
    _recetas.insert(0, nuevaReceta);
    notifyListeners();

    try {
      final response = await database.from('recetas').insert({
        'nombre': nuevaReceta.nombre,
        'descripcion': nuevaReceta.descripcion,
        'usuariouuid': nuevaReceta.usuarioUuid,
        'foto': nuevaReceta.foto,
        'tiempo': nuevaReceta.tiempo,
      }).select();


      if (response.isNotEmpty) {
        final index = _recetas.indexOf(nuevaReceta);
        if (index != -1) {
          _recetas[index] = RecetaModel.fromMap(response[0]);
          ordenarRecetas(_recetas);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error al crear receta en Supabase: $e");
      _recetas.remove(nuevaReceta);
      notifyListeners();
    }
  }

  Future<void> actualizarReceta(RecetaModel recetaActualizada) async {
    final backup = List<RecetaModel>.from(_recetas);

    final index = _recetas.indexWhere((r) => r.id == recetaActualizada.id);
    if (index != -1) {
      _recetas[index] = recetaActualizada;
      ordenarRecetas(_recetas);
      notifyListeners();
    }

    try {
      await database.from('recetas').update(recetaActualizada.toMap()).eq('id', recetaActualizada.id!);
    } catch (e) {
      debugPrint("Error al actualizar receta: $e");
      _recetas = backup;
      notifyListeners();
    }
  }

  Future<void> eliminarReceta(int id) async {
    final backup = List<RecetaModel>.from(_recetas);

    _recetas.removeWhere((r) => r.id == id);
    notifyListeners();

    try {
      await database.from('recetas').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error al eliminar receta: $e");
      _recetas = backup;
      notifyListeners();
    }
  }

  void addRecetaLocal(RecetaModel receta) {
    _recetas.add(receta);
    notifyListeners();
  }

  void removeRecetaLocal(int id) {
    _recetas.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void updateRecetaLocal(RecetaModel recetaActualizada) {
    final index = _recetas.indexWhere((r) => r.id == recetaActualizada.id);
    if (index != -1) {
      _recetas[index] = recetaActualizada;
      // ordenarRecetas(_recetas);
      notifyListeners();
    }
  }
}
