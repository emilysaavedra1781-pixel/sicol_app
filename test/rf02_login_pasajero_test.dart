// test/rf02_login_pasajero_test.dart
//
// Módulos cubiertos:
//   RF02 — Inicio de Sesión del Pasajero
//   RF40 — Bloqueo Automático de Cuenta por Intentos Fallidos
//
// Casos de prueba:
//   RF02: CP01, CP02, CP03, CP04, CP05
//   RF40: CP01, CP02, CP03
//
// Patrón: ARRANGE | ACT | ASSERT
// Firestore simulado con fake_cloud_firestore
// Firebase Auth simulado con firebase_auth_mocks + mock_exceptions
// Ejecutar: flutter test test/rf02_login_pasajero_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:sicol_app/services/auth_service.dart';

// ─── Helper: crea un usuario pasajero en el Firestore falso ──────────────────
Future<void> _crearUsuarioPasajero(
  FakeFirebaseFirestore db, {
  required String celular,
  String estado = 'activo',
  bool bloqueado = false,
  int intentosFallidos = 0,
}) async {
  await db.collection('usuarios').add({
    'uid': 'uid-test-pasajero',
    'celular': celular,
    'rol': 'pasajero',
    'nombre': 'Juan',
    'apellido': 'Pérez',
    'dni': '12345678',
    'estado': estado,
    'bloqueado': bloqueado,
    'intentosFallidos': intentosFallidos,
  });
}

// ─── Helper: configura MockFirebaseAuth para lanzar excepción en signIn ───────
void _hacerQueAuthFalle(MockFirebaseAuth mockAuth,
    {String code = 'wrong-password'}) {
  whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
      .on(mockAuth)
      .thenThrow(FirebaseAuthException(code: code));
}

void main() {
  group('RF02 — Inicio de Sesión del Pasajero', () {
    // ─────────────────────────────────────────────────────────────────────────
    // RF02 CP01
    // Flujo exitoso — login pasajero con celular y contraseña válidos
    // ─────────────────────────────────────────────────────────────────────────
    test('RF02 CP01 - Flujo exitoso: loginWithCelular retorna success=true '
        'y rol=pasajero con credenciales válidas', () async {
      // ARRANGE — Firestore falso con usuario activo; Auth mock que acepta sign-in
      final fakeDb = FakeFirebaseFirestore();
      await _crearUsuarioPasajero(fakeDb, celular: '987654321');
      final mockAuth = MockFirebaseAuth();
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT — el pasajero ingresa sus credenciales correctas
      final result = await service.loginWithCelular(
        celular: '987654321',
        password: 'contraseña123',
      );

      // ASSERT — el sistema valida y concede acceso
      expect(result['success'], isTrue,
          reason: 'Login con credenciales válidas debe retornar success=true');
      expect(result['rol'], equals('pasajero'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF02 CP02
    // Celular no registrado — usuario no encontrado en el sistema
    // ─────────────────────────────────────────────────────────────────────────
    test('RF02 CP02 - Celular no registrado: loginWithCelular retorna '
        'error=usuario_no_encontrado', () async {
      // ARRANGE — Firestore falso vacío (sin usuarios registrados)
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT — el pasajero ingresa un celular que no existe
      final result = await service.loginWithCelular(
        celular: '999999999',
        password: 'cualquierClave',
      );

      // ASSERT — el sistema indica que el usuario no está registrado
      expect(result['success'], isFalse);
      expect(result['error'], equals('usuario_no_encontrado'),
          reason: 'Celular no registrado debe retornar usuario_no_encontrado');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF02 CP03
    // Contraseña incorrecta — Firebase Auth lanza FirebaseAuthException
    // ─────────────────────────────────────────────────────────────────────────
    test('RF02 CP03 - Contraseña incorrecta: loginWithCelular retorna '
        'error=credenciales_invalidas cuando Firebase Auth falla', () async {
      // ARRANGE — Firestore con usuario activo; Auth mock configurado para fallar
      final fakeDb = FakeFirebaseFirestore();
      await _crearUsuarioPasajero(fakeDb, celular: '912345678');
      final mockAuth = MockFirebaseAuth();
      _hacerQueAuthFalle(mockAuth, code: 'wrong-password');
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT — el pasajero ingresa contraseña incorrecta
      final result = await service.loginWithCelular(
        celular: '912345678',
        password: 'claveIncorrecta',
      );

      // ASSERT — el sistema informa credenciales inválidas
      expect(result['success'], isFalse);
      expect(result['error'], equals('credenciales_invalidas'),
          reason: 'Contraseña incorrecta debe retornar credenciales_invalidas');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF02 CP04
    // Cuenta bloqueada — el sistema rechaza antes de llamar a Firebase Auth
    // ─────────────────────────────────────────────────────────────────────────
    test('RF02 CP04 - Cuenta bloqueada: loginWithCelular retorna '
        'error=cuenta_bloqueada sin llamar a Firebase Auth', () async {
      // ARRANGE — Firestore con usuario marcado como bloqueado
      final fakeDb = FakeFirebaseFirestore();
      await _crearUsuarioPasajero(
        fakeDb,
        celular: '911111111',
        bloqueado: true,
        estado: 'bloqueado',
      );
      final mockAuth = MockFirebaseAuth();
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT — pasajero con cuenta bloqueada intenta iniciar sesión
      final result = await service.loginWithCelular(
        celular: '911111111',
        password: 'cualquierClave',
      );

      // ASSERT — el sistema bloquea el acceso antes de llamar a Firebase Auth
      expect(result['success'], isFalse);
      expect(result['error'], equals('cuenta_bloqueada'),
          reason: 'Usuario bloqueado debe recibir cuenta_bloqueada inmediatamente');
      // Firebase Auth no fue contactado (currentUser sigue null)
      expect(mockAuth.currentUser, isNull);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF02 CP05
    // Bloqueo automático tras 3 intentos fallidos
    // ─────────────────────────────────────────────────────────────────────────
    test('RF02 CP05 - Bloqueo automático: después de 3 intentos fallidos '
        'el sistema bloquea la cuenta automáticamente', () async {
      // ARRANGE — usuario activo; Auth mock que siempre rechaza
      final fakeDb = FakeFirebaseFirestore();
      await _crearUsuarioPasajero(fakeDb,
          celular: '922222222', intentosFallidos: 0);
      final mockAuth = MockFirebaseAuth();
      _hacerQueAuthFalle(mockAuth);
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT — el pasajero falla 3 veces consecutivas
      final intento1 = await service.loginWithCelular(
          celular: '922222222', password: 'mal1');
      final intento2 = await service.loginWithCelular(
          celular: '922222222', password: 'mal2');
      final intento3 = await service.loginWithCelular(
          celular: '922222222', password: 'mal3');

      // ASSERT — los primeros 2 retornan credenciales_invalidas
      expect(intento1['error'], equals('credenciales_invalidas'));
      expect(intento2['error'], equals('credenciales_invalidas'));
      // El tercer intento activa el bloqueo automático
      expect(intento3['success'], isFalse);
      expect(intento3['error'], equals('cuenta_bloqueada'),
          reason: 'Al 3er intento fallido la cuenta debe quedar bloqueada');

      // Verificar que bloqueado=true fue persistido en Firestore
      final snap = await fakeDb
          .collection('usuarios')
          .where('celular', isEqualTo: '922222222')
          .limit(1)
          .get();
      final data = snap.docs.first.data();
      expect(data['bloqueado'], isTrue,
          reason: 'El campo bloqueado debe guardarse en Firestore tras 3 fallos');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  group('RF40 — Bloqueo Automático de Cuenta por Intentos Fallidos', () {
    // ─────────────────────────────────────────────────────────────────────────
    // RF40 CP01
    // Con 2 intentos previos, el siguiente fallo activa el bloqueo definitivo
    // ─────────────────────────────────────────────────────────────────────────
    test('RF40 CP01 - Bloqueo en el intento límite: con 2 intentos fallidos '
        'previos el 3° bloquea la cuenta y actualiza Firestore', () async {
      // ARRANGE — usuario con 2 intentos fallidos ya registrados
      final fakeDb = FakeFirebaseFirestore();
      await _crearUsuarioPasajero(fakeDb,
          celular: '933333333', intentosFallidos: 2);
      final mockAuth = MockFirebaseAuth();
      _hacerQueAuthFalle(mockAuth);
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT — el pasajero falla por 3ª vez (llega al límite)
      final resultado = await service.loginWithCelular(
        celular: '933333333',
        password: 'claveIncorrecta',
      );

      // ASSERT — la cuenta queda bloqueada en este intento
      expect(resultado['error'], equals('cuenta_bloqueada'));

      // Verificar persistencia en Firestore
      final snap = await fakeDb
          .collection('usuarios')
          .where('celular', isEqualTo: '933333333')
          .limit(1)
          .get();
      final data = snap.docs.first.data();
      expect(data['bloqueado'], isTrue);
      expect(data['estado'], equals('bloqueado'));
      expect(data['intentosFallidos'], equals(0),
          reason: 'intentosFallidos debe resetearse a 0 tras activar el bloqueo');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF40 CP02
    // Cuenta ya bloqueada — el sistema rechaza sin consultar Firebase Auth
    // ─────────────────────────────────────────────────────────────────────────
    test('RF40 CP02 - Cuenta ya bloqueada: el acceso es rechazado '
        'inmediatamente sin contactar Firebase Auth', () async {
      // ARRANGE — usuario en estado bloqueado
      final fakeDb = FakeFirebaseFirestore();
      await _crearUsuarioPasajero(
        fakeDb,
        celular: '944444444',
        bloqueado: true,
        estado: 'bloqueado',
      );
      final mockAuth = MockFirebaseAuth();
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT — intento de acceso con cuenta bloqueada
      final result = await service.loginWithCelular(
        celular: '944444444',
        password: 'cualquierClave',
      );

      // ASSERT — acceso denegado; Firebase Auth no fue contactado
      expect(result['success'], isFalse);
      expect(result['error'], equals('cuenta_bloqueada'));
      expect(mockAuth.currentUser, isNull,
          reason: 'Firebase Auth no debe ser invocado para cuentas bloqueadas');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF40 CP03
    // Desbloqueo de cuenta — restablece estado=activo y bloqueado=false
    // ─────────────────────────────────────────────────────────────────────────
    test('RF40 CP03 - Desbloqueo exitoso: desbloquearCuentaPorCelular '
        'restablece bloqueado=false y estado=activo en Firestore', () async {
      // ARRANGE — cuenta bloqueada
      final fakeDb = FakeFirebaseFirestore();
      await _crearUsuarioPasajero(
        fakeDb,
        celular: '955555555',
        bloqueado: true,
        estado: 'bloqueado',
        intentosFallidos: 0,
      );
      final mockAuth = MockFirebaseAuth();
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT — proceso de desbloqueo (tras recuperación de contraseña)
      await service.desbloquearCuentaPorCelular('955555555');

      // ASSERT — el usuario queda desbloqueado y activo
      final snap = await fakeDb
          .collection('usuarios')
          .where('celular', isEqualTo: '955555555')
          .limit(1)
          .get();
      final data = snap.docs.first.data();
      expect(data['bloqueado'], isFalse,
          reason: 'bloqueado debe ser false tras el desbloqueo');
      expect(data['estado'], equals('activo'),
          reason: 'estado debe volver a activo');
      expect(data['intentosFallidos'], equals(0));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // RF40 CP03-B
    // Desbloqueo de celular inexistente — operación segura sin excepción
    // ─────────────────────────────────────────────────────────────────────────
    test('RF40 CP03-B - Desbloqueo de celular inexistente: '
        'desbloquearCuentaPorCelular no lanza excepción', () async {
      // ARRANGE — Firestore vacío
      final fakeDb = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      final service = AuthService(auth: mockAuth, db: fakeDb);

      // ACT + ASSERT — no lanza excepción para celular no registrado
      expect(
        () async => await service.desbloquearCuentaPorCelular('000000000'),
        returnsNormally,
        reason: 'El desbloqueo de un celular inexistente no debe lanzar excepción',
      );
    });
  });
}
