class PasoReceta {
  final int numeroPaso;
  final String titulo;
  final String descripcion;

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
}