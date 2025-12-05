import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/step_recipe_model.dart';

class RecipeStepsProvider extends ChangeNotifier {
  final SupabaseClient database;
  final int recipeId;

  RecipeStepsProvider(this.database, this.recipeId);

  List<RecipeStep> _steps = [];
  List<RecipeStep> get steps => _steps;

  bool _isLoading = false;
  bool get isLoading => _isLoading;


  /// Carga los pasos de una receta desde la base de datos.
  ///
  /// Flujo principal:
  /// - Marca que se está cargando y actualiza la interfaz.
  /// - Busca en la tabla pasos_receta todos los pasos de la receta, ordenados por número.
  /// - Convierte los resultados en una lista de objetos PasoReceta y los guarda en _pasos.
  /// - Si ocurre un error, lo muestra por consola.
  /// - Al finalizar, desactiva el estado de carga y notifica los cambios.
  Future<void> loadSteps() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await database
          .from('pasos_receta')
          .select()
          .eq('receta_id', recipeId)
          .order('numero_paso', ascending: true);

      _steps = data.map<RecipeStep>(
            (map) => RecipeStep.fromJson(map, map['numero_paso']),
      ).toList();
    } catch (e) {
      if (kDebugMode) {
        print("Error al cargar pasos: $e");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// METODO PARA ACTUALIZAR UN PASO EN LA LISTA LOCAL
  void updateLocalStep(int stepNumber, RecipeStep updatedStep) {
    final index = _steps.indexWhere((p) => p.stepNumber == stepNumber);
    if (index != -1) {
      _steps[index] = updatedStep;
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
  Future<void> createStep(String title, String description) async {
    //CALCULAMOS EL NUEVO NUMERO DE PASO LOCALMENTE
    final newStepNumber = _steps.isEmpty ? 1 : _steps.last.stepNumber + 1;

    final newStep = RecipeStep(
      stepNumber: newStepNumber,
      title: title.trim(),
      description: description.trim(),
    );
    _steps.add(newStep);
    notifyListeners();
    try {
      await database.from('pasos_receta').insert(newStep.toMap(recipeId: recipeId));
    } catch (e) {
      if (kDebugMode) {
        print("Error al crear paso: $e");
      }
      _steps.removeWhere((p) => p.stepNumber == newStepNumber);
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
  Future<void> updateStep(RecipeStep step) async {
    final index = _steps.indexWhere((p) => p.stepNumber == step.stepNumber);
    if (index != -1) {
      _steps[index] = step;
      notifyListeners();
    }

    try {
      await database
          .from('pasos_receta')
          .update(step.toMap(recipeId: recipeId))
          .match({
        'receta_id': recipeId,
        'numero_paso': step.stepNumber,
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error al actualizar paso: $e");
      }
    }
  }

  /// Elimina un paso de la receta y actualiza la base de datos.
  ///
  /// Flujo principal:
  /// - Guarda una copia del paso eliminado por si hay errores.
  /// - Lo quita de la lista local y actualiza la interfaz.
  /// - Intenta borrarlo de la tabla pasos_receta.
  /// - Si ocurre un error, restaura el paso eliminado, reordena la lista y vuelve a notificar los cambios.
  Future<void> deleteStep(int stepNumber) async {
    final deletedStep = _steps.firstWhere((p) => p.stepNumber == stepNumber);
    _steps.removeWhere((p) => p.stepNumber == stepNumber);
    notifyListeners();

    try {
      await database
          .from('pasos_receta')
          .delete()
          .match({
        'receta_id': recipeId,
        'numero_paso': stepNumber,
      });

      if (kDebugMode) {
        print("Paso $stepNumber eliminado en Supabase");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error al eliminar paso: $e");
      }
      _steps.add(deletedStep);
      _steps.sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
      notifyListeners();
    }
  }
}