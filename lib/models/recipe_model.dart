/// Modelo que representa una receta con sus detalles
class RecipeModel {
  final int? id;
  String name;
  String description;
  String userUuid;
  String photo;
  String time;
  final String? shareCode;
  final String? importedCode;

  RecipeModel({
    this.id,
    required this.name,
    required this.description,
    required this.userUuid,
    required this.photo,
    required this.time,
    this.shareCode,
    this.importedCode,
  });

  /// Crea un RecipeModel desde un Map de la base de datos
  factory RecipeModel.fromMap(Map<String, dynamic> map) {
    return RecipeModel(
      id: map['id'] as int?,
      name: map['nombre']?.toString() ?? '',
      description: map['descripcion']?.toString() ?? '',
      userUuid: map['usuariouuid']?.toString() ?? '',
      photo: map['foto']?.toString() ?? '',
      time: map['tiempo']?.toString() ?? '',
      shareCode: map['codigo_compartir'],
      importedCode: map['codigo_importado'],
    );
  }

  /// Convierte el RecipeModel a un Map para la base de datos
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': name,
      'descripcion': description,
      'usuariouuid': userUuid,
      'foto': photo,
      'tiempo': time,
      if (shareCode != null) 'codigo_compartir': shareCode,
      if (importedCode != null) 'codigo_importado': importedCode,
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
    String? shareCode,
    String? importedCode,
  }) {
    return RecipeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      userUuid: userUuid ?? this.userUuid,
      photo: photo ?? this.photo,
      time: time ?? this.time,
      shareCode: shareCode ?? this.shareCode,
      importedCode: importedCode ?? this.importedCode,
    );
  }
}