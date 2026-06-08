import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ─── RF06: Colectivos disponibles ────────────────────────────────────────

  Stream<QuerySnapshot> getColectivosDisponibles({String? ruta}) {
    var query = _db
        .collection('viajes')
        .where('estado', isEqualTo: 'activo');
    if (ruta != null) {
      query = query.where('ruta', isEqualTo: ruta);
    }
    return query.snapshots();
  }

  // ─── RF07: Reservar asiento ───────────────────────────────────────────────

  Future<void> reservarAsiento({
    required String viajeId,
    required int numeroAsiento,
    required String nombreViajero,
    required String dniViajero,
    required String paradero,
  }) async {
    final viajeRef = _db.collection('viajes').doc(viajeId);

    await _db.runTransaction((tx) async {
      final viajeSnap = await tx.get(viajeRef);
      if (!viajeSnap.exists) throw Exception('Viaje no encontrado.');

      final data = viajeSnap.data()!;
      final asientos = Map<String, dynamic>.from(data['asientos'] ?? {});
      final key = 'asiento_$numeroAsiento';
      final asiento = asientos[key] as Map<String, dynamic>?;

      if (asiento == null) throw Exception('Asiento no existe.');
      if (asiento['estado'] != 'libre') {
        throw Exception('El asiento ya no está disponible.');
      }

      // Marcar como ocupado
      asientos[key] = {
        'numero': numeroAsiento,
        'estado': 'ocupado',
        'pasajero': {
          'uid': _uid,
          'nombre': nombreViajero,
          'dni': dniViajero,
          'paradero': paradero,
          'asiento': numeroAsiento,
        },
      };

      final asientosOcupados = (data['asientosOcupados'] ?? 0) + 1;
      final ingresoTotal = (data['ingresoTotal'] ?? 0) + 15;

      tx.update(viajeRef, {
        'asientos': asientos,
        'asientosOcupados': asientosOcupados,
        'ingresoTotal': ingresoTotal,
      });
    });

    // Registrar reserva en colección aparte
    await _db.collection('reservas').add({
      'pasajeroUid': _uid,
      'viajeId': viajeId,
      'numeroAsiento': numeroAsiento,
      'nombreViajero': nombreViajero,
      'dniViajero': dniViajero,
      'paradero': paradero,
      'monto': 15.0,
      'estado': 'confirmada',
      'creadoEn': FieldValue.serverTimestamp(),
    });
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
      final asientos = Map<String, dynamic>.from(data['asientos'] ?? {});
      final key = 'asiento_$numeroAsiento';

      asientos[key] = {
        'numero': numeroAsiento,
        'estado': 'libre',
        'pasajero': null,
      };

      final asientosOcupados =
      ((data['asientosOcupados'] ?? 1) - 1).clamp(0, 999);
      final ingresoTotal = ((data['ingresoTotal'] ?? 15) - 15).clamp(0, 99999);

      tx.update(viajeRef, {
        'asientos': asientos,
        'asientosOcupados': asientosOcupados,
        'ingresoTotal': ingresoTotal,
      });

      tx.update(reservaRef, {'estado': 'cancelada'});
    });
  }
}
