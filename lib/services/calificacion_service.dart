import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalificacionService {
  final _db = FirebaseFirestore.instance;

  /// CP03 — Verifica si el pasajero ya calificó este viaje
  Future<bool> yaCalificado({
    required String viajeId,
    required String pasajeroUid,
  }) async {
    final snap = await _db
        .collection('calificaciones')
        .where('viajeId', isEqualTo: viajeId)
        .where('pasajeroUid', isEqualTo: pasajeroUid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// CP06 — Verifica que el viaje esté finalizado antes de permitir calificar
  Future<bool> viajeEstaFinalizado(String viajeId) async {
    final snap = await _db.collection('viajes').doc(viajeId).get();
    if (!snap.exists) return false;
    final data = snap.data()!;
    return data['estado'] == 'finalizado';
  }

  /// CP01, CP02, CP04, CP05, CP07 — Guarda la calificación y recalcula promedio
  /// [puntuacion] debe estar entre 1 y 5 (CP04 mínimo 1, CP07 máximo 5)
  /// [comentario] es opcional (CP02)
  Future<void> calificarViaje({
    required String viajeId,
    required String conductorUid,
    required int puntuacion,
    String? comentario,
  }) async {
    final pasajeroUid = FirebaseAuth.instance.currentUser?.uid;
    if (pasajeroUid == null) throw Exception('Sesión no válida');

    // CP04 — Validar rango de puntuación
    if (puntuacion < 1 || puntuacion > 5) {
      throw Exception('La puntuación debe estar entre 1 y 5 estrellas');
    }

    // CP03 — Bloquear si ya calificó
    final duplicado = await yaCalificado(viajeId: viajeId, pasajeroUid: pasajeroUid);
    if (duplicado) {
      throw Exception('Ya calificaste este viaje. Solo se permite una calificación por viaje');
    }

    // CP06 — Solo viajes finalizados
    final finalizado = await viajeEstaFinalizado(viajeId);
    if (!finalizado) {
      throw Exception('Solo puedes calificar viajes finalizados');
    }

    final conductorRef = _db.collection('usuarios').doc(conductorUid);
    final calificacionRef = _db.collection('calificaciones').doc();

    // CP05 — Recalcular promedio dentro de una transacción
    await _db.runTransaction((tx) async {
      final conductorSnap = await tx.get(conductorRef);
      if (!conductorSnap.exists) throw Exception('Conductor no encontrado');

      final data = conductorSnap.data()!;
      final totalCalificaciones = (data['totalCalificaciones'] as num?)?.toInt() ?? 0;
      final promedioActual = (data['promedioCalificacion'] as num?)?.toDouble() ?? 0.0;

      // Fórmula: (promedioActual * total + nuevaPuntuacion) / (total + 1)
      final nuevoTotal = totalCalificaciones + 1;
      final nuevoPromedio =
          ((promedioActual * totalCalificaciones) + puntuacion) / nuevoTotal;

      // Guardar calificación
      tx.set(calificacionRef, {
        'viajeId': viajeId,
        'conductorUid': conductorUid,
        'pasajeroUid': pasajeroUid,
        'puntuacion': puntuacion,
        'comentario': comentario ?? '', // CP02 — comentario opcional
        'fechaCreacion': FieldValue.serverTimestamp(),
      });

      // Actualizar promedio del conductor
      tx.update(conductorRef, {
        'promedioCalificacion': double.parse(nuevoPromedio.toStringAsFixed(2)),
        'totalCalificaciones': nuevoTotal,
      });
    });
  }
}