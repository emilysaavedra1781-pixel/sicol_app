import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ─── RF06: Colectivos disponibles ────────────────────────────────────────

  Stream<QuerySnapshot> getColectivosDisponibles({String? ruta}) {
    var query = _db.collection('viajes').where('estado', isEqualTo: 'activo');
    if (ruta != null) {
      query = query.where('ruta', isEqualTo: ruta);
    }
    return query.snapshots();
  }

  // ─── RF10: Mis reservas ───────────────────────────────────────────────────

  Stream<QuerySnapshot> getMisReservas() {
    return _db
        .collection('reservas')
        .where('pasajeroUid', isEqualTo: _uid)
        .orderBy('creadoEn', descending: true)
        .snapshots();
  }

  // ─── RF11: Cancelar reserva ───────────────────────────────────────────────

  Future<void> cancelarReserva({
    required String reservaId,
    required String viajeId,
    required int numeroAsiento,
  }) async {
    final viajeRef = _db.collection('viajes').doc(viajeId);
    final reservaRef = _db.collection('reservas').doc(reservaId);

    await _db.runTransaction((tx) async {
      final viajeSnap = await tx.get(viajeRef);
      if (!viajeSnap.exists) throw Exception('Viaje no encontrado.');

      final data = viajeSnap.data()!;

      // ── Actualizar mapa asientos ─────────────────────────────────
      final asientosMapa = Map<String, dynamic>.from(data['asientos'] ?? {});
      final key = 'asiento_$numeroAsiento';
      asientosMapa[key] = {
        'numero': numeroAsiento,
        'estado': 'libre',
        'pasajero': null,
      };

      // ── Actualizar array asientosListaOcupados ───────────────────
      final ocupadosLista = List<int>.from(data['asientosListaOcupados'] ?? []);
      ocupadosLista.remove(numeroAsiento);

      final asientosOcupados = ocupadosLista.length;
      final ingresoTotal = ((data['ingresoTotal'] ?? 15) - 15).clamp(0, 99999);

      tx.update(viajeRef, {
        'asientos': asientosMapa,
        'asientosListaOcupados': ocupadosLista,
        'asientosOcupados': asientosOcupados,
        'ingresoTotal': ingresoTotal,
      });

      tx.update(reservaRef, {'estado': 'cancelada'});
    });
  }
}