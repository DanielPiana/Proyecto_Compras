import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recetaModel.dart';

class RecetaProvider with ChangeNotifier {
  final SupabaseClient database;
  String? userId;

  RecetaProvider(this.database, this.userId);

  List<RecetaModel> _recetas = [];

  List<RecetaModel> get recetas => _recetas;

  /// METODO PARA ESTABLECER UN USUARIO Y RECARGAR SUS RECETAS
  Future<void> setUserAndReload(String? uuid) async {
    userId = uuid;
    if (uuid == null) {
      _recetas = [];
      notifyListeners();
      return;
    }
    await cargarRecetas();
  }

  /// Carga las recetas del usuario desde la base de datos
  ///
  /// Flujo principal:
  /// - Consulta la tabla 'recetas' en la base de datos filtrando por [userId]
  /// - Convierte las recetas en una lista [RecetaModel]
  /// - Llama al metodo ordenarRecetas para ordenarlas alfabéticamente
  /// - Notifica a los listeners para actualizar la UI
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

  /// METODO PARA ORDENAR RECETAS ALFABETICAMENTE
  List<RecetaModel> ordenarRecetas(List<RecetaModel> recetas) {
    recetas.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return recetas;
  }

  /// Crea una receta en la base de datos y lo añade a la lista local
  ///
  /// Flujo principal:
  /// - Inserta la receta creada en la lista local
  /// - Notifica a los listeners para recargar la UI
  /// - Intenta insertar en la base de datos la [nuevaReceta] y la guarda en [response]
  /// - Si da error y [response] está vacío salta un error y borramos la receta
  /// de la lista local
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

  /// Actualiza un producto existente en la base de datos y en la lista local.
  ///
  /// Flujo principal:
  /// - Realiza una copia de respaldo de la lista local de productos
  /// - Busca la receta en la lista local y la reemplaza por la versión nueva
  /// - Intenta actualizar la receta en la base de datos
  /// - Si el proceso falla se restaura la copia de seguridad y noticamos a los
  /// listeners para actualizar la UI
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

  /// Elimina una receta de la base de datos y de la lista local.
  ///
  /// Flujo principal:
  /// - Realiza una copia de seguridad de la lista local de recetas
  /// - Elimina la receta de la lista local según su [id]
  /// - Notifica a los listeners para recargar la UI
  /// - Intenta eliminar la receta de la tabla 'recetas' de la base de datos
  /// - Si da error, se restaura la copia de seguridad y notifica a los listeners
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

  /// METODO PARA AÑADIR UNA RECETA A LA LISTA LOCAL
  void addRecetaLocal(RecetaModel receta) {
    _recetas.add(receta);
    notifyListeners();
  }

  /// METODO PARA ELIMINAR UNA RECETA A LA LISTA LOCAL
  void removeRecetaLocal(int id) {
    _recetas.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  /// METODO PARA ACTUALIZAR UNA RECETA EXISTENTE EN LA LISTA LOCAL
  void updateRecetaLocal(RecetaModel recetaActualizada) {
    final index = _recetas.indexWhere((r) => r.id == recetaActualizada.id);
    if (index != -1) {
      _recetas[index] = recetaActualizada;
      ordenarRecetas(_recetas);
      notifyListeners();
    }
  }
}
