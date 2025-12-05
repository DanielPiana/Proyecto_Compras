/// Modelo que representa un paso de una receta con su número, título y descripción
class RecipeStep {
  int stepNumber;
  String title;
  String description;

  RecipeStep({
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  /// Crea un RecipeStep desde un JSON de la base de datos
  factory RecipeStep.fromJson(Map<String, dynamic> json, int stepNumber) {
    return RecipeStep(
      stepNumber: stepNumber,
      title: json['titulo'] ?? '',
      description: json['descripcion'] ?? '',
    );
  }

  /// Convierte el RecipeStep a un Map para insertar/actualizar en Supabase
  Map<String, dynamic> toMap({required int recipeId}) {
    return {
      'receta_id': recipeId,
      'numero_paso': stepNumber,
      'titulo': title,
      'descripcion': description,
    };
  }

  /// Crea una copia del RecipeStep con los campos especificados modificados
  RecipeStep copyWith({
    int? stepNumber,
    String? title,
    String? description,
  }) {
    return RecipeStep(
      stepNumber: stepNumber ?? this.stepNumber,
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }
}
