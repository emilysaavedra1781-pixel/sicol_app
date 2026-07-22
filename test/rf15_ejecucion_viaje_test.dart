// test/rf15_ejecucion_viaje_test.dart
//
// Módulos cubiertos:
//   RF34 — Inicio de Viaje desde Ubicación Predeterminada
//   RF33 — Validación de Conductor en Servicio Activo
//   RF42 — Confirmación de Llenado de Asientos para Arranque
//
// Casos de prueba:
//   RF34: CP01, CP02, CP03, CP05
//   RF33: CP01, CP02, CP04
//   RF42: CP05
//
// Patrón: ARRANGE | ACT | ASSERT
// Firestore simulado con fake_cloud_firestore
// Firebase Auth simulado con firebase_auth_mocks
// LocationService simulado con Mock manual

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sicol_app/services/trip_service.dart';
import 'package:sicol_app/services/location_service.dart';

// ─── Mock de LocationService ────────────────────────────────────────────────
class MockLocationService extends Fake implements LocationService {
  bool withinRange = true;
  double distance = 10.0;
  String route = 'chosica_lima';

  @override
  Future<VerificacionUbicacion> verificarUbicacionParaIniciarViaje() async {
    return VerificacionUbicacion(
      dentroDelRango: withinRange,
      distanciaMetros: distance,
      rutaMasCercana: route,
    );
  }
}

void main() {
  group('RF34 · RF33 · RF42 — Ejecución de Viaje (Conductor)', () {
    
    // ─────────────────────────────────────────────────────────────────────────
    // RF34 — Inicio de Viaje (Geofencing)
    // ─────────────────────────────────────────────────────────────────────────

    test('RF34 CP01 - Inicio exitoso: crea viaje si está dentro del rango', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final mockLocation = MockLocationService();
      final service = TripService(auth: mockAuth, db: fakeDb, locationService: mockLocation);

      final conductorData = {
        'nombre': 'Pedro',
        'apellido': 'Picapiedra',
        'fotoUrl': 'url-foto',
        'conductorCodigo': 'COND-001',
        'vehiculo': {'capacidad': 4, 'placa': 'ABC-123'}
      };

      final result = await service.iniciarViaje(conductorData: conductorData);

      expect(result['success'], isTrue);
      expect(result['viajeId'], isNotNull);

      final doc = await fakeDb.collection('viajes').doc(result['viajeId']).get();
      expect(doc.data()!['estado'], equals('activo'));
      expect(doc.data()!['ruta'], equals('chosica_lima'));
    });

    test('RF34 CP02 - Ubicación incorrecta: retorna error outside-geofence', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final mockLocation = MockLocationService();
      mockLocation.withinRange = false;
      mockLocation.distance = 1500.0;

      final service = TripService(auth: mockAuth, db: fakeDb, locationService: mockLocation);

      final result = await service.iniciarViaje(conductorData: {});

      expect(result['success'], isFalse);
      expect(result['error'], equals('outside-geofence'));
      expect(result['distancia'], equals(1500.0));
    });

    test('RF34 CP02-B - Forzar inicio: crea viaje si se ignora la geocerca', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final mockLocation = MockLocationService();
      mockLocation.withinRange = false;

      final service = TripService(auth: mockAuth, db: fakeDb, locationService: mockLocation);

      final result = await service.iniciarViaje(conductorData: {}, ignorarGeocerca: true);

      expect(result['success'], isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF33 — Conductor en Servicio Activo
    // ─────────────────────────────────────────────────────────────────────────

    test('RF33 CP01 - Bloqueo simultáneo: no permite iniciar viaje si ya existe uno activo', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final uid = mockAuth.currentUser!.uid;

      // Crear viaje previo
      await fakeDb.collection('viajes').add({
        'conductorUid': uid,
        'estado': 'activo',
      });

      final service = TripService(auth: mockAuth, db: fakeDb);
      final result = await service.iniciarViaje(conductorData: {});

      expect(result['success'], isFalse);
      expect(result['error'], equals('active-trip-exists'));
    });

    test('RF33 CP04 - Reintento post-cierre: permite iniciar viaje tras cerrar el anterior', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final uid = mockAuth.currentUser!.uid;

      // Asegurar que el documento del conductor existe (requerido por cerrarViajeConDisponibilidad)
      await fakeDb.collection('usuarios').doc(uid).set({'rol': 'conductor'});

      // 1. Iniciar y cerrar viaje
      final service = TripService(auth: mockAuth, db: fakeDb, locationService: MockLocationService());
      final res1 = await service.iniciarViaje(conductorData: {});
      final vId = res1['viajeId'];

      await service.cerrarViajeConDisponibilidad(viajeId: vId, lat: 0, lng: 0);

      // 2. Intentar nuevo viaje
      final res2 = await service.iniciarViaje(conductorData: {});
      expect(res2['success'], isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF42 — Arranque del colectivo
    // ─────────────────────────────────────────────────────────────────────────

    test('RF42 CP05 - Hora de arranque: registra la hora exacta al arrancar', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final service = TripService(auth: mockAuth, db: fakeDb);

      final vRef = await fakeDb.collection('viajes').add({'estado': 'activo'});

      await service.arrancarColectivo(vRef.id);

      final doc = await fakeDb.collection('viajes').doc(vRef.id).get();
      expect(doc.data()!['estado'], equals('en_camino'));
      expect(doc.data()!['arranqueEn'], isNotNull);
      expect(doc.data()!['hora_arranque'], isNotNull);
    });
  });
}
