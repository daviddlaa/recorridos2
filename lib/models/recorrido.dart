class Recorrido {
  final int? id;
  final String? syncId;
  final String? userId; // Ahora opcional para soportarrecorridos antiguos
  final DateTime fecha;
  final String nombre;

  Recorrido({
    this.id,
    this.syncId,
    this.userId,
    required this.fecha,
    required this.nombre,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'fecha': fecha.toIso8601String(),
      'nombre': nombre,
    };
    if (id != null) map['id'] = id;
    if (syncId != null) map['sync_id'] = syncId;
    if (userId != null) map['user_id'] = userId;
    return map;
  }

  factory Recorrido.fromMap(Map<String, dynamic> map) {
    return Recorrido(
      id: map['id'] as int?,
      syncId: map['sync_id'] as String?,
      userId: map['user_id'] as String?,
      fecha: DateTime.parse(map['fecha'] as String),
      nombre: map['nombre'] as String,
    );
  }
}
