// test/rf07_rf50_compra_asientos_test.dart
//
// Módulos cubiertos:
//   RF07 — Compra de Pasaje y Selección de Asiento
//   RF50 — Registro de Viajero por Reserva
//
// Casos de prueba:
//   RF07: CP01, CP02, CP03
//   RF50: CP01, CP02
//
// Patrón: ARRANGE | ACT | ASSERT
// Firestore simulado con fake_cloud_firestore
// Firebase Auth simulado con firebase_auth_mocks
// Cloud Functions simulado con Fakes manuales
// Ejecutar: flutter test test/rf07_rf50_compra_asientos_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sicol_app/services/booking_service.dart';
import 'package:sicol_app/services/validation_service.dart';

// ─── Fakes para simular Firebase Functions ──────────────────────────────────
class FakeFirebaseFunctions extends Fake implements FirebaseFunctions {
  final HttpsCallable callable;
  FakeFirebaseFunctions(this.callable);
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) => callable;
}

class FakeHttpsCallable extends Fake implements HttpsCallable {
  final Future<dynamic> Function(dynamic) onCall;
  FakeHttpsCallable(this.onCall);
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final data = await onCall(parameters);
    return FakeHttpsCallableResult<T>(data as T);
  }
}

class FakeHttpsCallableResult<T> extends Fake implements HttpsCallableResult<T> {
  @override
  final T data;
  FakeHttpsCallableResult(this.data);
}

void main() {
  group('RF07 · RF50 — Compra y Selección de Asientos', () {
    
    // ─────────────────────────────────────────────────────────────────────────
    // RF07 CP01 & RF50 CP01
    // Flujo exitoso — Un solo asiento y registro de viajero
    // ─────────────────────────────────────────────────────────────────────────
    test('RF07 CP01 / RF50 CP01 - Reserva exitosa: llama a la función de backend con datos correctos', () async {
      // ARRANGE
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final fakeDb = FakeFirebaseFirestore();
      
      final fakeCallable = FakeHttpsCallable((params) async {
        // Validamos que los parámetros enviados al backend sean los correctos
        expect(params['viajeId'], equals('viaje-123'));
        expect(params['asientos'], equals([2]));
        expect(params['viajeros'][0]['nombre'], equals('Juan Perez'));
        
        return {
          'init_point': 'https://mercadopago.com/checkout/123',
          'reservaGroupId': 'group-abc'
        };
      });
      
      final service = BookingService(
        auth: mockAuth, 
        db: fakeDb, 
        functions: FakeFirebaseFunctions(fakeCallable)
      );

      // ACT
      final result = await service.bloquearAsientosYCrearPreferencia(
        viajeId: 'viaje-123',
        asientos: [2],
        viajeros: [{'asiento': 2, 'nombre': 'Juan Perez', 'dni': '12345678'}],
        monto: 15.0,
        paradero: 'Ate Vitarte',
      );

      // ASSERT
      expect(result['success'], isTrue);
      expect(result['initPoint'], contains('mercadopago.com'));
      expect(result['reservaGroupId'], equals('group-abc'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF07 CP02
    // Selección de múltiples asientos
    // ─────────────────────────────────────────────────────────────────────────
    test('RF07 CP02 - Múltiples asientos: envía lista de viajeros completa al backend', () async {
      // ARRANGE
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final fakeDb = FakeFirebaseFirestore();
      final fakeCallable = FakeHttpsCallable((params) async {
        final viajeros = params['viajeros'] as List;
        expect(viajeros.length, equals(2));
        expect(params['monto'], equals(30.0));
        return {'init_point': 'url', 'reservaGroupId': 'grp'};
      });
      
      final service = BookingService(
        auth: mockAuth, 
        db: fakeDb,
        functions: FakeFirebaseFunctions(fakeCallable)
      );

      // ACT
      final result = await service.bloquearAsientosYCrearPreferencia(
        viajeId: 'v1',
        asientos: [1, 2],
        viajeros: [
          {'asiento': 1, 'nombre': 'Juan', 'dni': '11111111'},
          {'asiento': 2, 'nombre': 'Maria', 'dni': '22222222'},
        ],
        monto: 30.0,
        paradero: 'Ñaña',
      );

      // ASSERT
      expect(result['success'], isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF07 CP03
    // Concurrencia — Asiento ocupado de imprevisto
    // ─────────────────────────────────────────────────────────────────────────
    test('RF07 CP03 - Concurrencia: maneja error already-exists del backend', () async {
      // ARRANGE
      final mockAuth = MockFirebaseAuth(signedIn: true);
      final fakeDb = FakeFirebaseFirestore();
      final fakeCallable = FakeHttpsCallable((params) async {
        // Simulamos que la Cloud Function lanza error de ya ocupado
        throw FirebaseFunctionsException(
          code: 'already-exists',
          message: 'Uno de los asientos elegidos acaba de ser ocupado.',
        );
      });
      
      final service = BookingService(
        auth: mockAuth, 
        db: fakeDb,
        functions: FakeFirebaseFunctions(fakeCallable)
      );

      // ACT
      final result = await service.bloquearAsientosYCrearPreferencia(
        viajeId: 'v1',
        asientos: [1],
        viajeros: [{'asiento': 1, 'nombre': 'Juan', 'dni': '11111111'}],
        monto: 15.0,
        paradero: 'Ñaña',
      );

      // ASSERT
      expect(result['success'], isFalse);
      expect(result['error'], equals('seats-occupied'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF50 CP02
    // Validación de campos obligatorios
    // ─────────────────────────────────────────────────────────────────────────
    test('RF50 CP02 - Validación: esViajeroValido detecta datos incompletos', () {
      // Nombre vacío
      expect(ValidationService.esViajeroValido('', '12345678'), isFalse);
      // DNI corto
      expect(ValidationService.esViajeroValido('Juan', '123'), isFalse);
      // DNI nulo
      expect(ValidationService.esViajeroValido('Juan', null), isFalse);
      // Válido
      expect(ValidationService.esViajeroValido('Juan Perez', '87654321'), isTrue);
    });
  });
}
