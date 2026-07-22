// test/rf11_rf28_rf41_cancelacion_pasajero_test.dart
//
// Módulos cubiertos:
//   RF11 — Cancelación de Reserva
//   RF28 — Reasignación de Asiento ante Cancelación
//   RF41 — Modificar Punto de Recojo Antes del Arranque
//
// Casos de prueba:
//   RF11: CP01, CP03
//   RF28: CP01, CP02
//   RF41: (Lógica en Widget - Se documenta limitación técnica)
//
// Patrón: ARRANGE | ACT | ASSERT
// Firestore simulado con fake_cloud_firestore
// Firebase Auth simulado con firebase_auth_mocks
// Ejecutar: flutter test test/rf11_rf28_rf41_cancelacion_pasajero_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sicol_app/services/booking_service.dart';

// ─── Fake para simular Firebase Functions ──────────────────────────────────
class FakeFirebaseFunctions extends Fake implements FirebaseFunctions {}

void main() {
  group('RF11 · RF28 — Cancelación y Reasignación', () {
    
    // ─────────────────────────────────────────────────────────────────────────
    // RF11 — Cancelación de Reserva
    // ─────────────────────────────────────────────────────────────────────────

    test('RF11 CP01 - Cancelación exitosa: libera asiento y descuenta ingreso', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final fakeFunctions = FakeFirebaseFunctions();
      final uid = mockAuth.currentUser!.uid;

      // 1. Crear viaje con un asiento ocupado
      final viajeRef = await fakeDb.collection('viajes').add({
        'estado': 'activo',
        'ingresoTotal': 15.0,
        'asientosListaOcupados': [3],
        'asientos': {
          'asiento_3': {
            'numero': 3,
            'estado': 'ocupado',
            'pasajero': {'uid': uid}
          }
        }
      });

      // 2. Crear reserva confirmada
      final resRef = await fakeDb.collection('reservas').add({
        'pasajeroUid': uid,
        'viajeId': viajeRef.id,
        'numeroAsiento': 3,
        'estado': 'confirmada',
        'monto': 15.0
      });

      final service = BookingService(db: fakeDb, auth: mockAuth, functions: fakeFunctions);

      // ACT
      await service.cancelarReserva(
        reservaId: resRef.id,
        viajeId: viajeRef.id,
        numeroAsiento: 3,
      );

      // ASSERT
      final vSnap = await viajeRef.get();
      final rSnap = await resRef.get();

      expect(rSnap.data()!['estado'], equals('cancelada'));
      expect(vSnap.data()!['ingresoTotal'], equals(0.0));
      expect(vSnap.data()!['asientosListaOcupados'], isEmpty);
      expect(vSnap.data()!['asientos']['asiento_3']['estado'], equals('libre'));
    });

    test('RF11 CP03 - Bloqueo de cancelación: lanza error si ya abordó', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final fakeFunctions = FakeFirebaseFunctions();
      
      final resRef = await fakeDb.collection('reservas').add({
        'estado': 'abordado'
      });

      final service = BookingService(db: fakeDb, auth: mockAuth, functions: fakeFunctions);

      // ACT & ASSERT
      expect(
        () => service.cancelarReserva(reservaId: resRef.id, viajeId: 'v1', numeroAsiento: 1),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('ya abordó'))),
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF28 — Reasignación de Asiento
    // ─────────────────────────────────────────────────────────────────────────

    test('RF28 CP01 - Cambio de asiento: actualiza viaje y reserva', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final fakeFunctions = FakeFirebaseFunctions();
      final uid = mockAuth.currentUser!.uid;

      final viajeRef = await fakeDb.collection('viajes').add({
        'asientosListaOcupados': [1],
        'asientos': {
          'asiento_1': {'numero': 1, 'estado': 'ocupado', 'pasajero': {'uid': uid}},
          'asiento_2': {'numero': 2, 'estado': 'libre'},
        }
      });

      final resRef = await fakeDb.collection('reservas').add({
        'pasajeroUid': uid,
        'viajeId': viajeRef.id,
        'numeroAsiento': 1,
        'estado': 'confirmada',
        'nombreViajero': 'Test User',
        'paradero': 'Ate'
      });

      final service = BookingService(db: fakeDb, auth: mockAuth, functions: fakeFunctions);

      // ACT
      await service.cambiarAsiento(
        reservaId: resRef.id,
        viajeId: viajeRef.id,
        nuevoAsiento: 2,
      );

      // ASSERT
      final vSnap = await viajeRef.get();
      final rSnap = await resRef.get();

      expect(rSnap.data()!['numeroAsiento'], equals(2));
      expect(vSnap.data()!['asientosListaOcupados'], contains(2));
      expect(vSnap.data()!['asientosListaOcupados'], isNot(contains(1)));
      expect(vSnap.data()!['asientos']['asiento_1']['estado'], equals('libre'));
      expect(vSnap.data()!['asientos']['asiento_2']['estado'], equals('ocupado'));
    });

    test('RF28 CP02 - Concurrencia reasignación: falla si el nuevo asiento se ocupa', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final fakeFunctions = FakeFirebaseFunctions();
      
      final viajeRef = await fakeDb.collection('viajes').add({
        'asientos': {
          'asiento_1': {'estado': 'ocupado'},
          'asiento_2': {'estado': 'bloqueado'}, // Alguien lo está comprando
        }
      });

      final resRef = await fakeDb.collection('reservas').add({
        'numeroAsiento': 1,
        'estado': 'confirmada'
      });

      final service = BookingService(db: fakeDb, auth: mockAuth, functions: fakeFunctions);

      // ACT & ASSERT
      expect(
        () => service.cambiarAsiento(reservaId: resRef.id, viajeId: viajeRef.id, nuevoAsiento: 2),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('ya fue tomado'))),
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF41 — Modificar Punto de Recojo
    // ─────────────────────────────────────────────────────────────────────────
    // NOTA: La lógica de RF41 reside actualmente en CambiarParaderoView.dart
    // dentro de un método privado _updateParadero. 
    // Debido a la regla de NO modificar código de producción para extraerlo a un servicio,
    // este CP queda como DEUDA TÉCNICA para ser cubierto con WidgetTester en el futuro.
  });
}
