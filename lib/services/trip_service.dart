import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ─── Verificar si tiene viaje activo (RF33) ───────────────────────────────

  Future<DocumentSnapshot?> getViajeActivo() async {
    final query = await _db
        .collection('viajes')
        .where('conductorUid', isEqualTo: _uid)
        .where('estado', isEqualTo: 'activo')
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first;
  }

  Stream<QuerySnapshot> getViajeActivoStream() {
    return _db
        .collection('viajes')
        .where('conductorUid', isEqualTo: _uid)
        .where('estado', isEqualTo: 'activo')
        .limit(1)
        .snapshots();
  }

  // ─── Iniciar viaje (RF34) ─────────────────────────────────────────────────

  Future<String> iniciarViaje({
    required String ruta, // 'chosica_lima' o 'lima_chosica'
    required Map<String, dynamic> conductorData,
  }) async {
    // Verificar que no haya viaje activo
    final activo = await getViajeActivo();
    if (activo != null) {
      throw Exception('Ya tienes un viaje activo. Ciérralo antes de iniciar uno nuevo.');
    }

    final vehiculo = conductorData['vehiculo'] as Map<String, dynamic>? ?? {};
    final capacidad = int.tryParse(vehiculo['capacidad']?.toString() ?? '4') ?? 4;

    // Crear asientos según capacidad
    final asientos = <String, dynamic>{};
    for (int i = 1; i <= capacidad; i++) {
      asientos['asiento_$i'] = {
        'numero': i,
        'estado': 'libre', // libre, bloqueado, ocupado
        'pasajero': null,
      };
    }

    final rutaLabel = ruta == 'chosica_lima' ? 'Chosica → Lima' : 'Lima → Chosica';

    final docRef = await _db.collection('viajes').add({
      'conductorUid': _uid,
      'conductorNombre': '${conductorData['nombre']} ${conductorData['apellido']}',
      'conductorCodigo': conductorData['codigoConductor'],
      'vehiculo': vehiculo,
      'ruta': ruta,
      'rutaLabel': rutaLabel,
      'estado': 'activo',
      'asientos': asientos,
      'capacidad': capacidad,
      'asientosOcupados': 0,
      'ingresoTotal': 0,
      'iniciadoEn': FieldValue.serverTimestamp(),
      'cerradoEn': null,
    });

    return docRef.id;
  }

  // ─── Cerrar viaje (RF18) ──────────────────────────────────────────────────

  Future<void> cerrarViaje(String viajeId) async {
    await _db.collection('viajes').doc(viajeId).update({
      'estado': 'finalizado',
      'cerradoEn': FieldValue.serverTimestamp(),
    });
  }

  // ─── Stream de pasajeros del viaje (RF15) ────────────────────────────────

  Stream<DocumentSnapshot> getViajeStream(String viajeId) {
    return _db.collection('viajes').doc(viajeId).snapshots();
  }

  // ─── Historial de viajes (RF36) ───────────────────────────────────────────

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