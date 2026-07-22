// test/rf06_seleccion_colectivo_test.dart
//
// Módulos cubiertos:
//   RF06 — Seleccionar Colectivo Disponible
//
// Casos de prueba:
//   RF06: CP01, CP02, CP03
//
// Patrón: ARRANGE | ACT | ASSERT
// Firestore simulado con fake_cloud_firestore
// Firebase Auth simulado con firebase_auth_mocks
// Ejecutar: flutter test test/rf06_seleccion_colectivo_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sicol_app/services/booking_service.dart';

void main() {
  group('RF06 — Seleccionar Colectivo Disponible', () {
    
    // ─────────────────────────────────────────────────────────────────────────
    // RF06 CP01
    // Flujo exitoso — Selección de colectivo
    // ─────────────────────────────────────────────────────────────────────────
    test('RF06 CP01 - Listar colectivos: getColectivosDisponibles retorna viajes con estado activo', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      
      // Crear un viaje activo
      await fakeDb.collection('viajes').add({
        'conductorUid': 'uid-1',
        'conductorNombre': 'Pedro Picapiedra',
        'estado': 'activo',
        'ruta': 'chosica_lima',
        'capacidad': 4,
        'asientosOcupados': 0,
        'iniciadoEn': FieldValue.serverTimestamp(),
      });

      // Crear un viaje finalizado (no debería aparecer)
      await fakeDb.collection('viajes').add({
        'conductorUid': 'uid-2',
        'conductorNombre': 'Pablo Marmol',
        'estado': 'finalizado',
        'ruta': 'chosica_lima',
        'capacidad': 4,
        'asientosOcupados': 0,
      });

      final service = BookingService(auth: mockAuth, db: fakeDb);

      // ACT
      final stream = service.getColectivosDisponibles(ruta: 'chosica_lima');
      final snap = await stream.first;

      // ASSERT
      expect(snap.docs.length, equals(1));
      final data = snap.docs.first.data() as Map<String, dynamic>;
      expect(data['conductorNombre'], equals('Pedro Picapiedra'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF06 CP02
    // Sin colectivos disponibles
    // ─────────────────────────────────────────────────────────────────────────
    test('RF06 CP02 - Sin colectivos: getColectivosDisponibles retorna lista vacía si no hay viajes activos', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final service = BookingService(auth: mockAuth, db: fakeDb);

      // ACT
      final stream = service.getColectivosDisponibles(ruta: 'chosica_lima');
      final snap = await stream.first;

      // ASSERT
      expect(snap.docs, isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF06 CP03
    // Concurrencia — El colectivo se llena antes de selección
    // ─────────────────────────────────────────────────────────────────────────
    test('RF06 CP03 - Concurrencia: verificarDisponibilidadViaje retorna false si el viaje está lleno (ocupados + bloqueados)', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      
      final viajeRef = await fakeDb.collection('viajes').add({
        'conductorUid': 'uid-1',
        'estado': 'activo',
        'capacidad': 4,
        'asientosOcupados': 3,
        'asientos': {
          'asiento_1': {'estado': 'ocupado'},
          'asiento_2': {'estado': 'ocupado'},
          'asiento_3': {'estado': 'ocupado'},
          'asiento_4': {'estado': 'bloqueado'}, // El último asiento está bloqueado por otro usuario
        },
      });

      final service = BookingService(auth: mockAuth, db: fakeDb);

      // ACT
      final disponible = await service.verificarDisponibilidadViaje(viajeRef.id);

      // ASSERT
      expect(disponible, isFalse, reason: 'Si (ocupados + bloqueados) >= capacidad, debe retornar false');
    });

    test('RF06 CP03-B - Disponibilidad: verificarDisponibilidadViaje retorna true si hay espacio real', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      
      final viajeRef = await fakeDb.collection('viajes').add({
        'conductorUid': 'uid-1',
        'estado': 'activo',
        'capacidad': 4,
        'asientosOcupados': 2,
        'asientos': {
          'asiento_1': {'estado': 'ocupado'},
          'asiento_2': {'estado': 'ocupado'},
          'asiento_3': {'estado': 'libre'},
          'asiento_4': {'estado': 'libre'},
        },
      });

      final service = BookingService(auth: mockAuth, db: fakeDb);

      // ACT
      final disponible = await service.verificarDisponibilidadViaje(viajeRef.id);

      // ASSERT
      expect(disponible, isTrue);
    });
  });
}
