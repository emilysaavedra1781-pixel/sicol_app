// test/rf03_recuperacion_pasajero_test.dart
//
// Módulos cubiertos:
//   RF03 — Recuperación de Contraseña del Pasajero
//
// Casos de prueba:
//   RF03: CP01, CP02, CP03, CP04, CP05
//
// Patrón: ARRANGE | ACT | ASSERT
// Firestore simulado con fake_cloud_firestore
// Firebase Auth simulado con firebase_auth_mocks
// Cloud Functions simulado con Fakes manuales
// Ejecutar: flutter test test/rf03_recuperacion_pasajero_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sicol_app/services/auth_service.dart';

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
  group('RF03 — Recuperación de Contraseña del Pasajero', () {
    
    // ─────────────────────────────────────────────────────────────────────────
    // RF03 CP01
    // Flujo exitoso — Cambio de contraseña
    // ─────────────────────────────────────────────────────────────────────────
    test('RF03 CP01 - Flujo exitoso: solicita, verifica y cambia contraseña', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      
      // Mock para las 3 funciones involucradas
      final fakeCallable = FakeHttpsCallable((params) async {
        if (params.containsKey('email') && !params.containsKey('otp')) {
          return {'success': true}; // solicitarOtpRecuperacion
        }
        if (params.containsKey('otp')) {
          return {'success': true, 'uid': 'user-123'}; // verificarOtpRecuperacion
        }
        if (params.containsKey('newPassword')) {
          return {'success': true}; // changePasswordSecure
        }
        return {};
      });

      final service = AuthService(
        auth: mockAuth, 
        db: fakeDb, 
        functions: FakeFirebaseFunctions(fakeCallable)
      );

      // 1. Solicitar
      final res1 = await service.solicitarOtpRecuperacion('pasajero@test.com');
      expect(res1['success'], isTrue);

      // 2. Verificar
      final res2 = await service.verificarOtpRecuperacion('pasajero@test.com', '123456');
      expect(res2['success'], isTrue);
      expect(res2['uid'], equals('user-123'));

      // 3. Cambiar
      final res3 = await service.cambiarPasswordSeguro('user-123', 'nueva_clave_2026');
      expect(res3['success'], isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF03 CP02
    // Usuario no registrado
    // ─────────────────────────────────────────────────────────────────────────
    test('RF03 CP02 - Usuario no registrado: retorna error usuario_no_encontrado', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      
      final fakeCallable = FakeHttpsCallable((params) async {
        throw FirebaseFunctionsException(code: 'not-found', message: 'User not found');
      });

      final service = AuthService(auth: mockAuth, db: fakeDb, functions: FakeFirebaseFunctions(fakeCallable));

      final result = await service.solicitarOtpRecuperacion('inexistente@test.com');
      
      expect(result['success'], isFalse);
      expect(result['error'], equals('usuario_no_encontrado'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF03 CP03
    // OTP incorrecto
    // ─────────────────────────────────────────────────────────────────────────
    test('RF03 CP03 - OTP incorrecto: retorna error invalid-otp', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      
      final fakeCallable = FakeHttpsCallable((params) async {
        throw FirebaseFunctionsException(code: 'invalid-argument', message: 'invalid-otp');
      });

      final service = AuthService(auth: mockAuth, db: fakeDb, functions: FakeFirebaseFunctions(fakeCallable));

      final result = await service.verificarOtpRecuperacion('pasajero@test.com', '000000');
      
      expect(result['success'], isFalse);
      expect(result['error'], equals('invalid-otp'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF03 CP04
    // OTP expirado
    // ─────────────────────────────────────────────────────────────────────────
    test('RF03 CP04 - OTP expirado: retorna error expired-otp', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      
      final fakeCallable = FakeHttpsCallable((params) async {
        throw FirebaseFunctionsException(code: 'deadline-exceeded', message: 'OTP expired');
      });

      final service = AuthService(auth: mockAuth, db: fakeDb, functions: FakeFirebaseFunctions(fakeCallable));

      final result = await service.verificarOtpRecuperacion('pasajero@test.com', '111111');
      
      expect(result['success'], isFalse);
      expect(result['error'], equals('expired-otp'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF03 CP05
    // Error de conexión
    // ─────────────────────────────────────────────────────────────────────────
    test('RF03 CP05 - Error de red: retorna error network-error', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      
      final fakeCallable = FakeHttpsCallable((params) async {
        throw Exception('SocketException: Connection failed');
      });

      final service = AuthService(auth: mockAuth, db: fakeDb, functions: FakeFirebaseFunctions(fakeCallable));

      final result = await service.solicitarOtpRecuperacion('pasajero@test.com');
      
      expect(result['success'], isFalse);
      expect(result['error'], equals('network-error'));
    });
  });
}
