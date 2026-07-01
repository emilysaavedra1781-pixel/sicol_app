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

  // ─── RF28: Cambiar asiento ante cancelación ──────────────────────────────

  Future<void> cambiarAsiento({
    required String reservaId,
    required String viajeId,
    required int nuevoAsiento,
  }) async {
    final viajeRef = _db.collection('viajes').doc(viajeId);
    final reservaRef = _db.collection('reservas').doc(reservaId);

    await _db.runTransaction((tx) async {
      final viajeSnap = await tx.get(viajeRef);
      if (!viajeSnap.exists) throw Exception('Viaje no encontrado.');
      final vData = viajeSnap.data()!;

      final reservaSnap = await tx.get(reservaRef);
      if (!reservaSnap.exists) throw Exception('Tu reserva no existe.');
      final rData = reservaSnap.data()!;
      final asientoAnterior = rData['numeroAsiento'];

      // CP02: Verificar si el nuevo asiento sigue libre (Concurrencia)
      final asientosMapa = Map<String, dynamic>.from(vData['asientos'] ?? {});
      final keyNuevo = 'asiento_$nuevoAsiento';
      
      if (asientosMapa[keyNuevo]['estado'] != 'libre') {
        throw Exception('Este asiento ya fue tomado por otro pasajero.');
      }

      // 1. Liberar asiento anterior
      final keyViejo = 'asiento_$asientoAnterior';
      asientosMapa[keyViejo] = {
        'numero': asientoAnterior,
        'estado': 'libre',
        'pasajero': null,
      };

      // 2. Ocupar nuevo asiento
      final pasajeroInfo = Map<String, dynamic>.from(asientosMapa[keyViejo]['pasajero'] ?? {
        'uid': _uid,
        'nombre': rData['nombreViajero'],
        'paradero': rData['paradero'],
      });
      pasajeroInfo['asiento'] = nuevoAsiento;

      asientosMapa[keyNuevo] = {
        'numero': nuevoAsiento,
        'estado': 'ocupado',
        'pasajero': pasajeroInfo,
      };

      // 3. Actualizar lista de ocupados
      final ocupadosLista = List<int>.from(vData['asientosListaOcupados'] ?? []);
      ocupadosLista.remove(asientoAnterior);
      ocupadosLista.add(nuevoAsiento);

      tx.update(viajeRef, {
        'asientos': asientosMapa,
        'asientosListaOcupados': ocupadosLista,
      });

      tx.update(reservaRef, {
        'numeroAsiento': nuevoAsiento,
      });
    });
  }

  Future<String?> getReservaIdForUserInTrip(String viajeId) async {
    final snap = await _db.collection('reservas')
        .where('pasajeroUid', isEqualTo: _uid)
        .where('viajeId', isEqualTo: viajeId)
        .where('estado', isEqualTo: 'confirmada')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first.id : null;
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
    final reservaRef = _db.collection('reservas').doc(reservaId);
    
    // CP06: Verificar si la reserva existe o ya fue cancelada
    final snap = await reservaRef.get();
    if (!snap.exists) throw Exception('Esta reserva no es válida.');
    if (snap.data()?['estado'] == 'cancelada') throw Exception('Esta reserva ya fue cancelada.');

    final viajeRef = _db.collection('viajes').doc(viajeId);

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