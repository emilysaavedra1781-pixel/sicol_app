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

    // ✅ Sin ruta — la asigna el primer pasajero que reserve
    final docRef = await _db.collection('viajes').add({
      'conductorUid': _uid,
      'conductorNombre':
      '${conductorData['nombre']} ${conductorData['apellido']}',
      'conductorCodigo': conductorData['codigoConductor'],
      'vehiculo': vehiculo,
      'ruta': null,      // se asigna cuando reserva el primer pasajero
      'rutaLabel': null,
      'estado': 'activo',
      'asientos': asientos,
      'capacidad': capacidad,
      'asientosOcupados': 0,
      'ingresoTotal': 0,
      'ubicacionActual': {
        'lat': -11.9347, // posición por defecto (Chosica)
        'lng': -76.6952,
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
      'forzadoPorAdmin': false,
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

  // ─── Cerrar viaje ─────────────────────────────────────────────────────────

  Future<void> cerrarViaje(String viajeId) async {
    await _db.collection('viajes').doc(viajeId).update({
      'estado': 'finalizado',
      'cerradoEn': FieldValue.serverTimestamp(),
    });
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
}