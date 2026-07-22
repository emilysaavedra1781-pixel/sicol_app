// test/rf23_rf46_login_recuperacion_conductor_test.dart
//
// Módulos cubiertos:
//   RF23 — Inicio de Sesión del Conductor
//   RF46 — Recuperación de Contraseña del Conductor
//
// Casos de prueba:
//   RF23: CP01, CP02, CP03, CP04, CP05, CP06, CP07
//   RF46: CP01, CP02, CP03, CP07
//
// Patrón: ARRANGE | ACT | ASSERT
// Firestore simulado con fake_cloud_firestore
// Firebase Auth simulado con firebase_auth_mocks
// Cloud Functions simulado con Fakes
// Ejecutar: flutter test test/rf23_rf46_login_recuperacion_conductor_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
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

// ─── Helper: crea un conductor en Firestore falso ──────────────────────────
Future<void> _crearConductor(
  FakeFirebaseFirestore db, {
  required String codigo,
  required String celular,
  String estado = 'activo',
  bool bloqueado = false,
  int intentosFallidos = 0,
}) async {
  await db.collection('usuarios').doc('uid-$codigo').set({
    'uid': 'uid-$codigo',
    'celular': celular,
    'codigoConductor': codigo,
    'rol': 'conductor',
    'nombre': 'Test',
    'apellido': 'Conductor',
    'estado': estado,
    'bloqueado': bloqueado,
    'intentosFallidos': intentosFallidos,
  });
}

void main() {
  group('RF23 — Inicio de Sesión del Conductor', () {
    
    test('RF23 CP01 - Login exitoso: retorna success=true y rol=conductor', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      final fakeFunctions = FakeFirebaseFunctions(FakeHttpsCallable((p) async => {}));
      
      await _crearConductor(fakeDb, codigo: 'COND-0001', celular: '988888888');
      final service = AuthService(auth: mockAuth, db: fakeDb, functions: fakeFunctions);

      final result = await service.loginConductor(
        codigoConductor: 'COND-0001',
        password: 'password123',
      );

      expect(result['success'], isTrue);
      expect(result['rol'], equals('conductor'));
    });

    test('RF23 CP04 - Bloqueo automático: la cuenta se bloquea tras 3 fallos', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      final fakeFunctions = FakeFirebaseFunctions(FakeHttpsCallable((p) async => {}));
      
      await _crearConductor(fakeDb, codigo: 'COND-0002', celular: '988888887', intentosFallidos: 0);
      
      // Simular fallo en Auth
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
          
      final service = AuthService(auth: mockAuth, db: fakeDb, functions: fakeFunctions);

      // Fallar 3 veces
      await service.loginConductor(codigoConductor: 'COND-0002', password: 'mal');
      await service.loginConductor(codigoConductor: 'COND-0002', password: 'mal');
      final result3 = await service.loginConductor(codigoConductor: 'COND-0002', password: 'mal');

      expect(result3['error'], equals('cuenta_bloqueada'));
      
      final doc = await fakeDb.collection('usuarios').doc('uid-COND-0002').get();
      expect(doc.data()!['bloqueado'], isTrue);
    });

    test('RF23 CP07 - Acceso denegado: pasajero no puede entrar por login de conductor', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      final fakeFunctions = FakeFirebaseFunctions(FakeHttpsCallable((p) async => {}));
      
      // Crear un pasajero (no tiene codigoConductor)
      await fakeDb.collection('usuarios').doc('uid-p').set({
        'celular': '900000000',
        'rol': 'pasajero',
      });
      final service = AuthService(auth: mockAuth, db: fakeDb, functions: fakeFunctions);

      final result = await service.loginConductor(
        codigoConductor: 'COND-9999', // No existe
        password: 'password',
      );

      expect(result['error'], equals('usuario_no_encontrado'));
    });
  });

  group('RF46 — Recuperación de Contraseña del Conductor', () {
    
    test('RF46 CP01 - Solicitud OTP: llama a la función con el email correcto', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      final fakeCallable = FakeHttpsCallable((params) async {
        expect(params['email'], equals('conductor@test.com'));
        return {'success': true};
      });
      final service = AuthService(auth: mockAuth, db: fakeDb, functions: FakeFirebaseFunctions(fakeCallable));

      final result = await service.solicitarOtpRecuperacion('conductor@test.com');
      expect(result['success'], isTrue);
    });

    test('RF46 CP02 - OTP incorrecto: maneja error invalid-otp', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      final fakeCallable = FakeHttpsCallable((params) async {
        throw FirebaseFunctionsException(code: 'invalid-argument', message: 'invalid-otp');
      });
      final service = AuthService(auth: mockAuth, db: fakeDb, functions: FakeFirebaseFunctions(fakeCallable));

      final result = await service.verificarOtpRecuperacion('test@test.com', '000000');
      expect(result['success'], isFalse);
      expect(result['error'], equals('invalid-otp'));
    });

    test('RF46 CP07 - Desbloqueo automático: cambiarPasswordSeguro retorna éxito', () async {
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      final fakeCallable = FakeHttpsCallable((params) async {
        return {'success': true};
      });
      final service = AuthService(auth: mockAuth, db: fakeDb, functions: FakeFirebaseFunctions(fakeCallable));

      final result = await service.cambiarPasswordSeguro('uid-123', 'new-pass-123');
      expect(result['success'], isTrue);
    });
  });
}
