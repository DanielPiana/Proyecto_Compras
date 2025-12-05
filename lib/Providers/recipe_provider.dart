import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe_model.dart';
import '../utils/text_normalizer.dart';

class RecipeProvider with ChangeNotifier {
  final SupabaseClient database;
  String? userId;

  RecipeProvider(this.database, this.userId);

  List<RecipeModel> _recipes = [];
  List<RecipeModel> get recipes => _recipes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<RecipeModel> filteredRecipes = [];
  String lastQuery = '';

  // GETTER PARA MOSTRAR RECETAS (FILTRADAS O TODAS)
  List<RecipeModel> get recipesToShow {
    if (filteredRecipes.isEmpty && lastQuery.trim().isEmpty) {
      return _recipes;
    }
    return filteredRecipes;
  }

  void setSearchText(String value) {
    lastQuery = value;

    if (value.trim().isEmpty) {
      filteredRecipes = [];
      notifyListeners();
      return;
    }

    final query = normalizeText(value);

    filteredRecipes = _recipes.where((recipe) {
      final name = normalizeText(recipe.name);
      final time = recipe.time.toString() ?? "";

      return name.contains(query) || time.contains(query);
    }).toList();

    notifyListeners();
  }

  /// METODO PARA ESTABLECER UN USUARIO Y RECARGAR SUS RECETAS
  Future<void> setUserAndReload(String? uuid) async {
    userId = uuid;
    if (uuid == null) {
      _recipes = [];
      notifyListeners();
      return;
    }
    await loadRecipes();
  }

  /// Carga las recetas del usuario desde la base de datos
  ///
  /// Flujo principal:
  /// - Consulta la tabla 'recetas' en la base de datos filtrando por [userId]
  /// - Convierte las recetas en una lista [RecipeModel]
  /// - Llama al metodo ordenarRecetas para ordenarlas alfabéticamente
  /// - Notifica a los listeners para actualizar la UI
  Future<void> loadRecipes() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await database
          .from('recetas')
          .select()
          .eq('usuariouuid', userId!)
          .order('id', ascending: false);

      _recipes = data.map<RecipeModel>((r) => RecipeModel.fromMap(r)).toList();
      sortRecipes(_recipes);
    } catch (e) {
      debugPrint("Error al cargar recetas: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// METODO PARA ORDENAR RECETAS ALFABETICAMENTE
  List<RecipeModel> sortRecipes(List<RecipeModel> recipes) {
    recipes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return recipes;
  }

  /// Crea una receta en la base de datos y lo añade a la lista local
  ///
  /// Flujo principal:
  /// - Inserta la receta creada en la lista local
  /// - Notifica a los listeners para recargar la UI
  /// - Intenta insertar en la base de datos la [newRecipe] y la guarda en [response]
  /// - Si da error y [response] está vacío salta un error y borramos la receta
  /// de la lista local
  Future<void> createRecipe(RecipeModel newRecipe) async {
    _recipes.insert(0, newRecipe);
    notifyListeners();

    try {
      final response = await database.from('recetas').insert({
        'nombre': newRecipe.name,
        'descripcion': newRecipe.description,
        'usuariouuid': newRecipe.userUuid,
        'foto': newRecipe.photo,
        'tiempo': newRecipe.time,
      }).select();


      if (response.isNotEmpty) {
        final index = _recipes.indexOf(newRecipe);
        if (index != -1) {
          _recipes[index] = RecipeModel.fromMap(response[0]);
          sortRecipes(_recipes);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error al crear receta en Supabase: $e");
      _recipes.remove(newRecipe);
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
  Future<void> updateRecipe(RecipeModel updatedRecipe) async {
    final backup = List<RecipeModel>.from(_recipes);

    final index = _recipes.indexWhere((r) => r.id == updatedRecipe.id);

    if (index != -1) {
      _recipes[index] = updatedRecipe;
      sortRecipes(_recipes);
      notifyListeners();
    }
    try {
      await database.from('recetas').update(updatedRecipe.toMap()).eq('id', updatedRecipe.id!);
    } catch (e) {
      debugPrint("Error al actualizar receta: $e");
      _recipes = backup;
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
  Future<void> deleteRecipe(int id) async {
    final backup = List<RecipeModel>.from(_recipes);

    _recipes.removeWhere((r) => r.id == id);
    notifyListeners();

    try {
      await database.from('recetas').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error al eliminar receta: $e");
      _recipes = backup;
      notifyListeners();
    }
  }

  /// METODO PARA AÑADIR UNA RECETA A LA LISTA LOCAL
  void addLocalRecipe(RecipeModel recipe) {
    _recipes.add(recipe);
    notifyListeners();
  }

  /// METODO PARA ELIMINAR UNA RECETA A LA LISTA LOCAL
  void removeLocalRecipe(int id) {
    _recipes.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  /// METODO PARA ACTUALIZAR UNA RECETA EXISTENTE EN LA LISTA LOCAL
  void updateLocalRecipe(RecipeModel updatedRecipe) {
    final index = _recipes.indexWhere((r) => r.id == updatedRecipe.id);
    if (index != -1) {
      _recipes[index] = updatedRecipe;
      sortRecipes(_recipes);
      notifyListeners();
    }
  }
}
