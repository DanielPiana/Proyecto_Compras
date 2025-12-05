/// Modelo que representa una receta con sus detalles
class RecipeModel {
  final int? id;
  String name;
  String description;
  String userUuid;
  String photo;
  String time;

  RecipeModel({
    this.id,
    required this.name,
    required this.description,
    required this.userUuid,
    required this.photo,
    required this.time
  });

  /// Crea un RecipeModel desde un Map de la base de datos
  factory RecipeModel.fromMap(Map<String, dynamic> map) {
    return RecipeModel(
        id: map['id'] as int?,
        name: map['nombre']?.toString() ?? '',
        description: map['descripcion']?.toString() ?? '',
        userUuid: map['usuariouuid']?.toString() ?? '',
        photo: map['foto']?.toString() ?? '',
        time: map ['tiempo']?.toString() ?? ''
    );
  }

  /// Convierte el RecipeModel a un Map para la base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': name,
      'descripcion': description,
      'usuariouuid': userUuid,
      'foto': photo,
      'tiempo': time
    };
  }

  /// Crea una copia del RecipeModel con los campos especificados modificados
  RecipeModel copyWith({
    int? id,
    String? name,
    String? description,
    String? userUuid,
    String? photo,
    String? time,
  }) {
    return RecipeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      userUuid: userUuid ?? this.userUuid,
      photo: photo ?? this.photo,
      time: time ?? this.time,
    );
  }


}
