import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/paradero_model.dart';

/// DAO — Centraliza el acceso a la colección 'paraderos' en Firestore.
/// Ninguna otra clase realiza consultas directamente a esta colección.
class ParaderoService {
  final FirebaseFirestore _db;

  ParaderoService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ─── Paraderos hardcodeados como fallback sin internet ─────────────────────
  static final List<ParaderoModel> _fallback = [
    ParaderoModel(
      id: 'p01', nombre: 'Chosica Centro',
      referencia: 'Plaza de Armas de Chosica', ruta: 'chosica_lima', orden: 1,
    ),
    ParaderoModel(
      id: 'p02', nombre: 'Ate Vitarte',
      referencia: 'Óvalo de Ate', ruta: 'chosica_lima', orden: 2,
    ),
    ParaderoModel(
      id: 'p03', nombre: 'Santa Anita',
      referencia: 'Av. Circunvalación', ruta: 'chosica_lima', orden: 3,
    ),
    ParaderoModel(
      id: 'p04', nombre: 'La Molina',
      referencia: 'Av. La Molina cruce con Javier Prado', ruta: 'chosica_lima', orden: 4,
    ),
    ParaderoModel(
      id: 'p05', nombre: 'Surco (La Ronda)',
      referencia: 'Av. Primavera', ruta: 'chosica_lima', orden: 5,
    ),
    ParaderoModel(
      id: 'p06', nombre: 'San Isidro',
      referencia: 'Av. Javier Prado Oeste', ruta: 'chosica_lima', orden: 6,
    ),
    ParaderoModel(
      id: 'p07', nombre: 'Miraflores',
      referencia: 'Av. Larco', ruta: 'chosica_lima', orden: 7,
    ),
    ParaderoModel(
      id: 'p08', nombre: 'Lima Centro',
      referencia: 'Plaza San Martín', ruta: 'chosica_lima', orden: 8,
    ),
  ];

  /// Obtiene los paraderos activos de la ruta Chosica→Lima desde Firestore.
  /// Si falla (sin internet), retorna la lista de fallback.
  Future<List<ParaderoModel>> getParaderosActivos({
    String ruta = 'chosica_lima',
  }) async {
    try {
      final snap = await _db
          .collection('paraderos')
          .where('ruta', isEqualTo: ruta)
          .where('activo', isEqualTo: true)
          .orderBy('orden')
          .get();

      if (snap.docs.isEmpty) return _fallback;

      return snap.docs
          .map((d) => ParaderoModel.fromMap(d.data(), d.id))
          .toList();
    } catch (_) {
      // EX01: Sin internet → retorna última versión conocida (fallback)
      return _fallback;
    }
  }

  /// Filtra paraderos por nombre para el autocompletado (búsqueda local).
  List<ParaderoModel> filtrar(List<ParaderoModel> todos, String query) {
    if (query.trim().isEmpty) return todos;
    final q = query.toLowerCase();
    return todos
        .where((p) =>
            p.nombre.toLowerCase().contains(q) ||
            p.referencia.toLowerCase().contains(q))
        .toList();
  }
}
