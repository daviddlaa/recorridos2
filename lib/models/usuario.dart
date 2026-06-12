class Usuario {
  final String id;
  final String nombre;
  final String claveSincronizacion;
  final DateTime fechaCreado;

  Usuario({
    required this.id,
    required this.nombre,
    required this.claveSincronizacion,
    required this.fechaCreado,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'clave_sincronizacion': claveSincronizacion,
      'fecha_creado': fechaCreado.toIso8601String(),
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      claveSincronizacion: map['clave_sincronizacion'] as String,
      fechaCreado: DateTime.parse(map['fecha_creado'] as String),
    );
  }
}
