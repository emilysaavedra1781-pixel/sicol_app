// test/rf01_registro_pasajero_test.dart
//
// Módulos cubiertos:
//   RF01 — Registro de Usuario (Pasajero)
//
// Casos de prueba:
//   RF01: CP01, CP02, CP03, CP04, CP05
//
// Patrón: ARRANGE | ACT | ASSERT
// Firestore simulado con fake_cloud_firestore
// Firebase Auth simulado con firebase_auth_mocks + mock_exceptions
// Ejecutar: flutter test test/rf01_registro_pasajero_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:sicol_app/services/auth_service.dart';
import 'package:sicol_app/services/validation_service.dart';

void main() {
  group('RF01 — Registro de Usuario (Pasajero)', () {
    
    // ─────────────────────────────────────────────────────────────────────────
    // RF01 CP01
    // Registro exitoso — Flujo completo
    // ─────────────────────────────────────────────────────────────────────────
    test('RF01 CP01 - Registro exitoso: registerPasajero crea el usuario en Auth y Firestore', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT
      final result = await service.registerPasajero(
        dni: '12345678',
        nombre: 'Juan',
        apellido: 'Perez',
        celular: '987654321',
        email: 'juan@test.com',
        password: 'password123',
        fechaNacimiento: '01/01/1990',
      );

      // ASSERT
      expect(result['success'], isTrue);
      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser!.email, equals('987654321@sicol.pe'));

      final snap = await fakeDb.collection('usuarios').doc(mockAuth.currentUser!.uid).get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['dni'], equals('12345678'));
      expect(snap.data()!['rol'], equals('pasajero'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF01 CP02
    // Validación de datos incompletos
    // ─────────────────────────────────────────────────────────────────────────
    test('RF01 CP02 - Validación de datos: ValidationService detecta campos inválidos', () {
      // DNI corto
      expect(ValidationService.validarDni('123'), equals('El DNI debe tener 8 dígitos'));
      // DNI vacío
      expect(ValidationService.validarDni(''), equals('El DNI es requerido'));
      // Celular inválido
      expect(ValidationService.validarCelular('123'), equals('9 dígitos (Ej. 9XXXXXXXX)'));
      // Email inválido
      expect(ValidationService.validarEmail('test'), equals('Email inválido'));
      // Password corto
      expect(ValidationService.validarPassword('123'), equals('Mínimo 8 caracteres'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF01 CP03
    // Celular ya registrado
    // ─────────────────────────────────────────────────────────────────────────
    test('RF01 CP03 - Celular duplicado: registerPasajero retorna error duplicate-phone', () async {
      // ARRANGE
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      
      // Simular que el correo sintético ya existe en Auth
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
          
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT
      final result = await service.registerPasajero(
        dni: '12345678',
        nombre: 'Juan',
        apellido: 'Perez',
        celular: '987654321',
        email: 'juan@test.com',
        password: 'password123',
        fechaNacimiento: '01/01/1990',
      );

      // ASSERT
      expect(result['success'], isFalse);
      expect(result['error'], equals('duplicate-phone'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF01 CP04
    // OTP incorrecto
    // ─────────────────────────────────────────────────────────────────────────
    test('RF01 CP04 - OTP incorrecto: verifyOTP lanza FirebaseAuthException', () async {
      // ARRANGE
      final mockAuth = MockFirebaseAuth();
      final fakeDb = FakeFirebaseFirestore();
      whenCalling(Invocation.method(#signInWithCredential, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'invalid-verification-code'));
          
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT & ASSERT
      expect(
        () => service.verifyOTP(verificationId: 'vid', smsCode: '000000'),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'invalid-verification-code')),
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF01 CP05
    // Fallo por falta de internet
    // ─────────────────────────────────────────────────────────────────────────
    test('RF01 CP05 - Error de red: registerPasajero retorna error network-error', () async {
      // ARRANGE
      final mockAuth = MockFirebaseAuth();
      final fakeDb = FakeFirebaseFirestore();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));
          
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT
      final result = await service.registerPasajero(
        dni: '12345678',
        nombre: 'Juan',
        apellido: 'Perez',
        celular: '987654321',
        email: 'juan@test.com',
        password: 'password123',
        fechaNacimiento: '01/01/1990',
      );

      // ASSERT
      expect(result['success'], isFalse);
      expect(result['error'], equals('network-error'));
    });
  });
}
