import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ─── Verificar si tiene viaje activo ─────────────────────────────────────

  Future<DocumentSnapshot?> getViajeActivo() async {
    final query = await _db
        .collection('viajes')
        .where('conductorUid', isEqualTo: _uid)
        .where('estado', whereIn: ['activo', 'en_camino'])
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first;
  }

  Stream<QuerySnapshot> getViajeActivoStream() {
    return _db
        .collection('viajes')
        .where('conductorUid', isEqualTo: _uid)
        .where('estado', whereIn: ['activo', 'en_camino'])
        .limit(1)
        .snapshots();
  }

  // ─── Iniciar viaje (sin ruta — la define el primer pasajero) ─────────────

  Future<String> iniciarViaje({
    required Map<String, dynamic> conductorData,
    double? lat,
    double? lng,
    String? ruta,
  }) async {
    final activo = await getViajeActivo();
    if (activo != null) {
      throw Exception(
          'Ya tienes un viaje activo. Ciérralo antes de iniciar uno nuevo.');
    }

    final vehiculo =
        conductorData['vehiculo'] as Map<String, dynamic>? ?? {};
    final capacidad =
        int.tryParse(vehiculo['capacidad']?.toString() ?? '4') ?? 4;

    final asientos = <String, dynamic>{};
    for (int i = 1; i <= capacidad; i++) {
      asientos['asiento_$i'] = {
        'numero': i,
        'estado': 'libre',
        'pasajero': null,
      };
    }

    String? rutaLabel;
    if (ruta == 'chosica_lima') rutaLabel = 'Chosica → Lima';
    if (ruta == 'lima_chosica') rutaLabel = 'Lima → Chosica';

    // ✅ Si se detecta la ruta por ubicación, se asigna de una vez
    final docRef = await _db.collection('viajes').add({
      'conductorUid': _uid,
      'conductorNombre':
      '${conductorData['nombre']} ${conductorData['apellido']}',
      'conductorFotoUrl': conductorData['fotoUrl'],
      'conductorCodigo': conductorData['conductorCodigo'],
      'vehiculo': vehiculo,
      'ruta': ruta,      
      'rutaLabel': rutaLabel,
      'estado': 'activo',
      'asientos': asientos,
      'capacidad': capacidad,
      'asientosOcupados': 0,
      'ingresoTotal': 0,
      'ubicacionActual': {
        'lat': lat ?? -11.9347, 
        'lng': lng ?? -76.6952,
        'timestamp': FieldValue.serverTimestamp(),
      },
      'forzadoPorAdmin': false,
      'iniciadoEn': FieldValue.serverTimestamp(),
      'arranqueEn': null,
      'cerradoEn': null,
    });

    return docRef.id;
  }

  // ─── Conductor arranca el colectivo ───────────────────────────────────────

  Future<void> arrancarColectivo(String viajeId) async {
    await _db.collection('viajes').doc(viajeId).update({
      'estado': 'en_camino',
      'arranqueEn': FieldValue.serverTimestamp(),
      'hora_arranque': FieldValue.serverTimestamp(), // CP05: Registrar hora de arranque
      'forzadoPorAdmin': false,
    });
  }

  Future<void> abordarPasajero(String viajeId, int numAsiento, String reservaId) async {
    await _db.runTransaction((tx) async {
      final vRef = _db.collection('viajes').doc(viajeId);
      final rRef = _db.collection('reservas').doc(reservaId);
      
      final vSnap = await tx.get(vRef);
      final vData = vSnap.data()!;
      final asientos = Map<String, dynamic>.from(vData['asientos'] ?? {});
      final key = 'asiento_$numAsiento';
      
      if (asientos[key] != null) {
        asientos[key]['estado'] = 'abordado';
      }
      
      tx.update(vRef, {'asientos': asientos});
      tx.update(rRef, {'estado': 'abordado'});
    });
  }

  // ─── Admin: Forzar arranque ───────────────────────────────────────────────

  Future<void> forzarArranque(String viajeId) async {
    await _db.collection('viajes').doc(viajeId).update({
      'estado': 'en_camino',
      'arranqueEn': FieldValue.serverTimestamp(),
      'forzadoPorAdmin': true,
    });
  }

  // ─── Cerrar viaje y quedar disponible (RF42) ──────────────────────────────

  Future<void> cerrarViajeConDisponibilidad({
    required String viajeId,
    required double lat,
    required double lng,
  }) async {
    final batch = _db.batch();
    final viajeRef = _db.collection('viajes').doc(viajeId);
    final conductorRef = _db.collection('usuarios').doc(_uid);

    // 1. Obtener datos del viaje para liberar asientos (CP04)
    final vSnap = await viajeRef.get();
    final vData = vSnap.data() as Map<String, dynamic>;
    final capacidad = (vData['capacidad'] as num?)?.toInt() ?? 4;
    
    final asientosLiberados = <String, dynamic>{};
    for (int i = 1; i <= capacidad; i++) {
      asientosLiberados['asiento_$i'] = {
        'numero': i,
        'estado': 'libre',
        'pasajero': null,
      };
    }

    // 2. Finalizar viaje (sin limpiar asientos para conservar historial)
    batch.update(viajeRef, {
      'estado': 'finalizado',
      'cerradoEn': FieldValue.serverTimestamp(),
    });

    // 3. Actualizar disponibilidad del conductor (CP06)
    batch.update(conductorRef, {
      'ubicacion_actual': {
        'lat': lat,
        'lng': lng,
        'timestamp': FieldValue.serverTimestamp(),
      },
      'disponible': true,
      'viajeActivoId': null,
    });

    // 4. Marcar reservas como finalizadas para que los pasajeros puedan calificar
    final reservasSnap = await _db.collection('reservas')
        .where('viajeId', isEqualTo: viajeId)
        .where('estado', whereIn: ['confirmada', 'abordado'])
        .get();
    
    for (var doc in reservasSnap.docs) {
      batch.update(doc.reference, {'estado': 'finalizada'});
    }

    await batch.commit();
  }

  // ─── Stream de un viaje específico ───────────────────────────────────────

  Stream<DocumentSnapshot> getViajeStream(String viajeId) {
    return _db.collection('viajes').doc(viajeId).snapshots();
  }

  // ─── Historial de viajes ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHistorialViajes() async {
    final query = await _db
        .collection('viajes')
        .where('conductorUid', isEqualTo: _uid)
        .where('estado', isEqualTo: 'finalizado')
        .orderBy('cerradoEn', descending: true)
        .get();
    return query.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ─── Verificar si todos los pasajeros bajaron ─────────────────────────────
  Future<bool> todosBajaron(String viajeId) async {
    final snap = await _db
        .collection('reservas')
        .where('viajeId', isEqualTo: viajeId)
        .where('estado', whereIn: ['confirmada', 'abordado'])
        .limit(1)
        .get();
    return snap.docs.isEmpty;
  }
}