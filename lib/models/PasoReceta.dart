class PasoReceta {
  int numeroPaso;
  String titulo;
  String descripcion;

  PasoReceta({
    required this.numeroPaso,
    required this.titulo,
    required this.descripcion,
  });

  factory PasoReceta.fromJson(Map<String, dynamic> json, int numeroPaso) {
    return PasoReceta(
      numeroPaso: numeroPaso,
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
    );
  }

  /// 👇 Este método lo usamos al insertar/actualizar en Supabase
  Map<String, dynamic> toMap({required int recetaId}) {
    return {
      'receta_id': recetaId,
      'numero_paso': numeroPaso,
      'titulo': titulo,
      'descripcion': descripcion,
    };
  }

  PasoReceta copyWith({
    int? numeroPaso,
    String? titulo,
    String? descripcion,
  }) {
    return PasoReceta(
      numeroPaso: numeroPaso ?? this.numeroPaso,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
    );
  }
}
