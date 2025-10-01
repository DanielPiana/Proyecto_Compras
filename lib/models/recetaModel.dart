class RecetaModel {
  final int? id;
  String nombre;
  String descripcion;
  String usuarioUuid;
  String foto;
  String tiempo;

  RecetaModel({
    this.id,
    required this.nombre,
    required this.descripcion,
    required this.usuarioUuid,
    required this.foto,
    required this.tiempo
  });

  factory RecetaModel.fromMap(Map<String, dynamic> map) {
    return RecetaModel(
        id: map['id'] as int?,
        nombre: map['nombre']?.toString() ?? '',
        descripcion: map['descripcion']?.toString() ?? '',
        usuarioUuid: map['usuariouuid']?.toString() ?? '',
        foto: map['foto']?.toString() ?? '',
        tiempo: map ['tiempo']?.toString() ?? ''
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'usuariouuid': usuarioUuid,
      'foto': foto,
      'tiempo': tiempo
    };
  }

  RecetaModel copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    String? usuarioUuid,
    String? foto,
    String? tiempo,
  }) {
    return RecetaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      usuarioUuid: usuarioUuid ?? this.usuarioUuid,
      foto: foto ?? this.foto,
      tiempo: tiempo ?? this.tiempo,
    );
  }


}
