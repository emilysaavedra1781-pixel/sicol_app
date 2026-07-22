// test/rf08_confirmacion_compra_test.dart
//
// Módulos cubiertos:
//   RF08 — Confirmación de Compra de Pasaje
//
// Casos de prueba:
//   RF08: CP01, CP03, CP04
//
// Patrón: ARRANGE | ACT | ASSERT
// Firestore simulado con fake_cloud_firestore
// Firebase Auth simulado con firebase_auth_mocks
// Ejecutar: flutter test test/rf08_confirmacion_compra_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sicol_app/services/booking_service.dart';

// ─── Fake para simular Firebase Functions ──────────────────────────────────
class FakeFirebaseFunctions extends Fake implements FirebaseFunctions {}

void main() {
  group('RF08 — Confirmación de Compra de Pasaje', () {
    
    // ─────────────────────────────────────────────────────────────────────────
    // RF08 CP03
    // Cancelación manual — liberación de asientos y eliminación de reservas
    // ─────────────────────────────────────────────────────────────────────────
    test('RF08 CP03 - Cancelación manual: libera asientos en viaje y borra documentos de reserva', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final fakeFunctions = FakeFirebaseFunctions();
      
      // 1. Crear viaje con asientos bloqueados
      final viajeRef = await fakeDb.collection('viajes').add({
        'asientos': {
          'asiento_5': {'numero': 5, 'estado': 'bloqueado', 'bloqueado_por': 'user-123'},
          'asiento_6': {'numero': 6, 'estado': 'bloqueado', 'bloqueado_por': 'user-123'},
        }
      });
      
      // 2. Crear reservas temporales
      await fakeDb.collection('reservas').add({
        'reservaGroupId': 'group-999',
        'viajeId': viajeRef.id,
        'estado': 'bloqueada',
        'numeroAsiento': 5
      });
      await fakeDb.collection('reservas').add({
        'reservaGroupId': 'group-999',
        'viajeId': viajeRef.id,
        'estado': 'bloqueada',
        'numeroAsiento': 6
      });

      final service = BookingService(db: fakeDb, auth: mockAuth, functions: fakeFunctions);

      // ACT
      await service.cancelarBloqueoTemporal(
        viajeId: viajeRef.id,
        reservaGroupId: 'group-999',
        asientos: [5, 6],
      );

      // ASSERT
      // Verificar que los asientos en el viaje volvieron a estar LIBRES
      final vSnap = await viajeRef.get();
      final asientos = vSnap.data()!['asientos'] as Map;
      expect(asientos['asiento_5']['estado'], equals('libre'));
      expect(asientos['asiento_6']['estado'], equals('libre'));

      // Verificar que los documentos de reserva fueron ELIMINADOS
      final resSnap = await fakeDb.collection('reservas')
          .where('reservaGroupId', isEqualTo: 'group-999')
          .get();
      expect(resSnap.docs, isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF08 CP04
    // Expiración del tiempo
    // ─────────────────────────────────────────────────────────────────────────
    test('RF08 CP04 - Expiración: liberarAsientosExpirados cambia estado de bloqueado a libre', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final fakeFunctions = FakeFirebaseFunctions();
      
      final viajeRef = await fakeDb.collection('viajes').add({
        'asientos': {
          'asiento_1': {'numero': 1, 'estado': 'bloqueado'},
        }
      });
      
      final service = BookingService(db: fakeDb, auth: mockAuth, functions: fakeFunctions);

      // ACT
      await service.liberarAsientosExpirados(viajeRef.id, [1]);

      // ASSERT
      final vSnap = await viajeRef.get();
      expect(vSnap.data()!['asientos']['asiento_1']['estado'], equals('libre'));
    });
  });
}
