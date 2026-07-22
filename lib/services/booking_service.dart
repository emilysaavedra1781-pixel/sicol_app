import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class BookingService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  BookingService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  String get _uid => _auth.currentUser!.uid;

  // ─── RF06: Colectivos disponibles ────────────────────────────────────────

  Stream<QuerySnapshot> getColectivosDisponibles({String? ruta}) {
    var query = _db.collection('viajes').where('estado', isEqualTo: 'activo');
    if (ruta != null) {
      query = query.where('ruta', isEqualTo: ruta);
    }
    return query.snapshots();
  }

  /// Verifica si un viaje aún tiene asientos disponibles (considerando ocupados y bloqueados).
  /// CP03: Usa una transacción para garantizar consistencia en entornos concurrentes.
  Future<bool> verificarDisponibilidadViaje(String viajeId) async {
    try {
      final vRef = _db.collection('viajes').doc(viajeId);
      return await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(vRef);
        if (!snap.exists) return false;

        final data = snap.data() as Map<String, dynamic>;
        final capacidad = (data['capacidad'] as num?)?.toInt() ?? 4;
        final ocupados = (data['asientosOcupados'] as num?)?.toInt() ?? 0;

        final asientos = data['asientos'] as Map<String, dynamic>? ?? {};
        int bloqueados = 0;
        asientos.forEach((k, v) {
          if (v['estado'] == 'bloqueado') bloqueados++;
        });

        return (ocupados + bloqueados < capacidad);
      });
    } catch (e) {
      return false;
    }
  }

  /// Llama a la Cloud Function para bloquear asientos y generar la preferencia de pago.
  /// RF07 CP01, CP02, CP03
  Future<Map<String, dynamic>> bloquearAsientosYCrearPreferencia({
    required String viajeId,
    required List<int> asientos,
    required List<Map<String, dynamic>> viajeros,
    required double monto,
    required String paradero,
  }) async {
    try {
      final user = _auth.currentUser;
      final result = await _functions.httpsCallable('bloquearYCrearPreferencia').call({
        'viajeId': viajeId,
        'pasajeroId': user?.uid,
        'asientos': asientos,
        'viajeros': viajeros,
        'monto': monto,
        'email': user?.email,
        'paradero': paradero,
      });

      return {
        'success': true,
        'initPoint': result.data['init_point'],
        'reservaGroupId': result.data['reservaGroupId'],
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.code == 'already-exists' ? 'seats-occupied' : e.message,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
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

  Stream<DocumentSnapshot> getReservaStream(String reservaId) {
    return _db.collection('reservas').doc(reservaId).snapshots();
  }

  /// Libera asientos que fueron bloqueados temporalmente y elimina las reservas asociadas.
  /// RF08 CP03
  Future<void> cancelarBloqueoTemporal({
    required String viajeId,
    required String reservaGroupId,
    required List<int> asientos,
  }) async {
    try {
      final batch = _db.batch();

      // 1. Liberar asientos en el viaje
      final vRef = _db.collection('viajes').doc(viajeId);
      final vSnap = await vRef.get();
      if (vSnap.exists) {
        final vData = vSnap.data() as Map<String, dynamic>;
        final asientosMapa = Map<String, dynamic>.from(vData['asientos'] ?? {});

        for (var n in asientos) {
          final key = 'asiento_$n';
          if (asientosMapa[key]?['estado'] == 'bloqueado') {
            asientosMapa[key] = {
              'numero': n,
              'estado': 'libre',
              'pasajero': null,
            };
          }
        }
        batch.update(vRef, {'asientos': asientosMapa});
      }

      // 2. Eliminar reservas temporales
      final resSnap = await _db.collection('reservas')
          .where('reservaGroupId', isEqualTo: reservaGroupId)
          .get();

      for (var doc in resSnap.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Libera asientos de una reserva que ya expiró por tiempo (backend TTL).
  /// RF08 CP04
  Future<void> liberarAsientosExpirados(String viajeId, List<int> asientos) async {
    final vRef = _db.collection('viajes').doc(viajeId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(vRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      final asientosMapa = Map<String, dynamic>.from(data['asientos'] ?? {});
      
      for (var n in asientos) {
        final key = 'asiento_$n';
        if (asientosMapa[key]?['estado'] == 'bloqueado') {
          asientosMapa[key] = {'numero': n, 'estado': 'libre', 'pasajero': null};
        }
      }
      tx.update(vRef, {'asientos': asientosMapa});
    });
  }
}
