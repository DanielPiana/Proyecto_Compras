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


  /// Carga los pasos de una receta desde la base de datos.
  ///
  /// Flujo principal:
  /// - Marca que se está cargando y actualiza la interfaz.
  /// - Busca en la tabla pasos_receta todos los pasos de la receta, ordenados por número.
  /// - Convierte los resultados en una lista de objetos PasoReceta y los guarda en _pasos.
  /// - Si ocurre un error, lo muestra por consola.
  /// - Al finalizar, desactiva el estado de carga y notifica los cambios.
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
      print("Error al cargar pasos: $e");
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }

  /// METODO PARA ACTUALIZAR UN PASO EN LA LISTA LOCAL
  void actualizarPasoLocal(int numeroPaso, PasoReceta pasoActualizado) {
    final index = _pasos.indexWhere((p) => p.numeroPaso == numeroPaso);
    if (index != -1) {
      _pasos[index] = pasoActualizado;
      notifyListeners();
    }
  }

  /// Crea un nuevo paso para la receta y lo guarda en la base de datos.
  ///
  /// Flujo principal:
  /// - Calcula el número del nuevo paso según la cantidad actual de pasos.
  /// - Crea un objeto PasoReceta con el título y la descripción dados.
  /// - Añade el paso a la lista local y actualiza la interfaz.
  /// - Intenta guardar el paso en la tabla pasos_receta.
  /// - Si ocurre un error, elimina el paso recién añadido y vuelve a notificar los cambios.
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
      print("Error al crear paso: $e");
      _pasos.removeWhere((p) => p.numeroPaso == nuevoNumeroPaso);
      notifyListeners();
    }
  }

  /// Actualiza un paso existente de la receta tanto en la lista local como en la base de datos.
  ///
  /// Flujo principal:
  /// - Busca el paso en la lista por su número de paso.
  /// - Si lo encuentra, lo reemplaza por la nueva versión y actualiza la interfaz.
  /// - Intenta guardar los cambios en la tabla pasos_receta.
  /// - Si ocurre un error, lo muestra por consola.
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
      print("Error al actualizar paso: $e");
    }
  }

  /// Elimina un paso de la receta y actualiza la base de datos.
  ///
  /// Flujo principal:
  /// - Guarda una copia del paso eliminado por si hay errores.
  /// - Lo quita de la lista local y actualiza la interfaz.
  /// - Intenta borrarlo de la tabla pasos_receta.
  /// - Si ocurre un error, restaura el paso eliminado, reordena la lista y vuelve a notificar los cambios.
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

      print("Paso $numeroPaso eliminado en Supabase");
    } catch (e) {
      print("Error al eliminar paso: $e");
      _pasos.add(eliminado);
      _pasos.sort((a, b) => a.numeroPaso.compareTo(b.numeroPaso));
      notifyListeners();
    }
  }

}
