import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IncidenciaService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('incidencias');

  /// Crea una nueva incidencia.
  /// - Si [rolUsuario] es 'pasajero', [viajeId] es OBLIGATORIO
  ///   (solo puede reportar tras confirmar una reserva).
  /// - Si [rolUsuario] es 'conductor', [viajeId] es opcional.
  Future<void> crearIncidencia({
    required String rolUsuario, // 'conductor' | 'pasajero'
    required String tipo,
    required String descripcion,
    String? viajeId,
    int? minutosRetraso,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('No hay un usuario autenticado.');
    }
    if (descripcion.trim().isEmpty) {
      throw Exception('La descripción no puede estar vacía.');
    }
    if (rolUsuario == 'pasajero' && (viajeId == null || viajeId.isEmpty)) {
      throw Exception(
          'El pasajero solo puede reportar incidencias de un viaje con reserva confirmada.');
    }

    await _col.add({
      'usuarioId': uid,
      'rolUsuario': rolUsuario,
      'tipo': tipo,
      'descripcion': descripcion.trim(),
      'viajeId': viajeId,
      'minutosRetraso': minutosRetraso,
      'estado': 'pendiente',
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Historial de incidencias reportadas por el usuario actual.
  /// NOTA: Requiere un índice compuesto en Firestore: usuarioId (asc) + creadoEn (desc)
  Future<List<Map<String, dynamic>>> getMisIncidencias() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final snap = await _col
        .where('usuarioId', isEqualTo: uid)
        .orderBy('creadoEn', descending: true)
        .get();

    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }
}