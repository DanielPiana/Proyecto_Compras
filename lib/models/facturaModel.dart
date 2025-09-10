class FacturaModel {
  final int? id; // autoincrementable
  final double precio;
  final String fecha;
  final String usuariouuid;

  FacturaModel({
    this.id,
    required this.precio,
    required this.fecha,
    required this.usuariouuid,
  });

  // Convertir de Map (por ejemplo desde Supabase) a FacturaModel
  factory FacturaModel.fromMap(Map<String, dynamic> map) {
    return FacturaModel(
      id: map['id'] as int?,
      precio: (map['precio'] as num).toDouble(),
      fecha: map['fecha'] as String,
      usuariouuid: map['usuariouuid'] as String,
    );
  }

  // Convertir a Map (para insertar en Supabase)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'precio': precio,
      'fecha': fecha,
      'usuariouuid': usuariouuid,
    };
  }
}
