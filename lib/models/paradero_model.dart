class ParaderoModel {
  final String id;
  final String nombre;
  final String referencia;
  final String ruta; // 'chosica_lima' | 'lima_chosica'
  final int orden;
  final bool activo;

  ParaderoModel({
    required this.id,
    required this.nombre,
    required this.referencia,
    required this.ruta,
    required this.orden,
    this.activo = true,
  });

  factory ParaderoModel.fromMap(Map<String, dynamic> map, String id) {
    return ParaderoModel(
      id: id,
      nombre: map['nombre'] ?? '',
      referencia: map['referencia'] ?? '',
      ruta: map['ruta'] ?? 'chosica_lima',
      orden: map['orden'] ?? 0,
      activo: map['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'referencia': referencia,
      'ruta': ruta,
      'orden': orden,
      'activo': activo,
    };
  }
}
