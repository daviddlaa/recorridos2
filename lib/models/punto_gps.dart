class PuntoGps {
  final int? id;
  final String? syncId;
  final int recorridoId;
  final double latitud;
  final double longitud;
  final DateTime fechaHora;

  PuntoGps({
    this.id,
    this.syncId,
    required this.recorridoId,
    required this.latitud,
    required this.longitud,
    required this.fechaHora,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'recorrido_id': recorridoId,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_hora': fechaHora.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    if (syncId != null) map['sync_id'] = syncId;
    return map;
  }

  factory PuntoGps.fromMap(Map<String, dynamic> map) {
    return PuntoGps(
      id: map['id'] as int?,
      syncId: map['sync_id'] as String?,
      recorridoId: map['recorrido_id'] as int,
      latitud: map['latitud'] as double,
      longitud: map['longitud'] as double,
      fechaHora: DateTime.parse(map['fecha_hora'] as String),
    );
  }
}
