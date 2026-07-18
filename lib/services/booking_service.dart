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

  /// Cancela una reserva del pasajero. Solo permitido si el estado es 'confirmada'.
  Future<void> cancelarReserva({
    required String reservaId,
    required String viajeId,
    required int numeroAsiento,
  }) async {
    final reservaRef = _db.collection('reservas').doc(reservaId);
    
    // Validar estado actual de la reserva
    final snap = await reservaRef.get();
    if (!snap.exists) throw Exception('Esta reserva no es válida.');
    
    final estadoActual = snap.data()?['estado'];
    if (estadoActual == 'cancelada') throw Exception('Esta reserva ya fue cancelada.');
    if (estadoActual == 'abordado') throw Exception('No es posible cancelar: el pasajero ya abordó el vehículo.');
    if (estadoActual != 'confirmada') throw Exception('No puedes cancelar la reserva en su estado actual ($estadoActual).');

    await _ejecutarCancelacionCore(reservaId, viajeId, numeroAsiento, 'cancelada');
  }

  /// Función especial para Administradores que permite cancelar sin restricciones de estado.
  Future<void> forzarCancelacionAdmin({
    required String reservaId,
    required String viajeId,
    required int numeroAsiento,
    required String adminUid,
    String motivo = 'Cancelación forzada por administrador',
  }) async {
    await _ejecutarCancelacionCore(reservaId, viajeId, numeroAsiento, 'cancelada', auditData: {
      'canceladoPorAdmin': true,
      'adminId': adminUid,
      'motivoAdmin': motivo,
      'fechaCancelacionAdmin': FieldValue.serverTimestamp(),
    });
  }

  /// Lógica compartida para liberar asiento y marcar reserva como cancelada.
  Future<void> _ejecutarCancelacionCore(
    String reservaId, 
    String viajeId, 
    int numeroAsiento, 
    String nuevoEstado,
    {Map<String, dynamic>? auditData}
  ) async {
    final viajeRef = _db.collection('viajes').doc(viajeId);
    final reservaRef = _db.collection('reservas').doc(reservaId);

    await _db.runTransaction((tx) async {
      final viajeSnap = await tx.get(viajeRef);
      if (!viajeSnap.exists) throw Exception('Viaje no encontrado.');

      final data = viajeSnap.data()!;

      // 1. Liberar el asiento en el mapa del viaje
      final asientosMapa = Map<String, dynamic>.from(data['asientos'] ?? {});
      final key = 'asiento_$numeroAsiento';
      asientosMapa[key] = {
        'numero': numeroAsiento,
        'estado': 'libre',
        'pasajero': null,
      };

      // 2. Actualizar lista de ocupados y totales
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

      // 3. Marcar reserva como cancelada (con auditoría si aplica)
      final Map<String, dynamic> updateReserva = {'estado': nuevoEstado};
      if (auditData != null) updateReserva.addAll(auditData);
      
      tx.update(reservaRef, updateReserva);
    });
  }
}