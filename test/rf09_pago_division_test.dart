// test/rf09_pago_division_test.dart
//
// Módulos cubiertos:
//   RF09 — Pago de Pasaje con División Automática
//
// Casos de prueba:
//   RF09: CP01, CP03, CP04
//
// Patrón: ARRANGE | ACT | ASSERT
// Firestore simulado con fake_cloud_firestore
// Firebase Auth simulado con firebase_auth_mocks
// Ejecutar: flutter test test/rf09_pago_division_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sicol_app/services/booking_service.dart';
import 'package:sicol_app/models/comprobante_model.dart';
import 'package:cloud_functions/cloud_functions.dart';

// ─── Fake para simular Firebase Functions ──────────────────────────────────
class FakeFirebaseFunctions extends Fake implements FirebaseFunctions {}

void main() {
  group('RF09 — Pago y División Automática', () {
    
    // ─────────────────────────────────────────────────────────────────────────
    // RF09 CP01
    // Generación de comprobante — Mapeo de datos desde Firestore
    // ─────────────────────────────────────────────────────────────────────────
    test('RF09 CP01 - Comprobante: ComprobanteModel mapea correctamente los datos del backend', () {
      // ARRANGE
      final now = DateTime.now();
      final data = {
        'nombreViajero': 'Juan Perez',
        'numeroAsiento': 3,
        'monto': 15.0,
        'paymentId': 'PAY-123',
        'comprobante': {
          'codigoComprobante': 'CMP-TEST',
          'fechaEmision': Timestamp.fromDate(now),
          'conductorNombre': 'Pedro Picapiedra',
          'placaVehiculo': 'ABC-123',
          'asiento': 3,
          'paradero': 'Ate Vitarte',
          'codigoVerificacion': 'XYZ78',
          'monto': 15.0
        }
      };

      // ACT
      final model = ComprobanteModel.fromFirestore(data, 'fallback-id');

      // ASSERT
      expect(model.codigoComprobante, equals('CMP-TEST'));
      expect(model.viajeroNombre, equals('Juan Perez'));
      expect(model.montoFormateado, equals('S/ 15.00'));
      expect(model.paymentId, equals('PAY-123'));
      expect(model.fechaFormateada, contains('${now.day}/${now.month}/${now.year}'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF09 CP03 / CP04
    // Monitoreo de estado de reserva (Expiración / Concurrencia)
    // ─────────────────────────────────────────────────────────────────────────
    test('RF09 CP04 - Concurrencia: getReservaStream permite detectar cambios de estado en tiempo real', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final fakeFunctions = FakeFirebaseFunctions();
      
      final resRef = await fakeDb.collection('reservas').add({
        'estado': 'bloqueada',
        'viajeId': 'v1',
      });

      final service = BookingService(db: fakeDb, auth: mockAuth, functions: fakeFunctions);

      // ACT & ASSERT
      final stream = service.getReservaStream(resRef.id);
      
      // Esperar el siguiente valor del stream
      final expectation = expectLater(
        stream.map((snap) => (snap.data() as Map<String, dynamic>)['estado']),
        emitsInOrder(['bloqueada', 'error_concurrencia']),
      );

      // Simular que el backend marca la reserva como fallida por concurrencia (CP04)
      await resRef.update({'estado': 'error_concurrencia'});
      
      await expectation;
    });

    test('RF09 CP01-B - Fallback: ComprobanteModel usa datos base si el objeto comprobante no existe aún', () {
      // ARRANGE
      final data = {
        'nombreViajero': 'Maria Lopez',
        'numeroAsiento': 5,
        'monto': 15.0,
        'paradero': 'Ñaña',
        'codigoVerificacion': '12345',
        // 'comprobante' es nulo mientras el backend lo genera
      };

      // ACT
      final model = ComprobanteModel.fromFirestore(data, 'ABCDEFGH123');

      // ASSERT
      expect(model.codigoComprobante, equals('ABCDEFGH')); // Fallback: primeros 8 del ID
      expect(model.viajeroNombre, equals('Maria Lopez'));
      expect(model.asiento, equals(5));
      expect(model.paradero, equals('Ñaña'));
    });
  });
}
