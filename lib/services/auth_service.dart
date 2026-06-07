import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── MODO PRUEBA ───────────────────────────────────────────────────────────────
// Cambiar a false cuando vayas a producción real
const bool kModoSimulacion = true;
const String kCodigoPrueba = '123456';
// ──────────────────────────────────────────────────────────────────────────────

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // ── Stream estado de autenticación ─────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Enviar OTP ──────────────────────────────────────────────────────────
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    if (kModoSimulacion) {
      // Simula que el SMS fue enviado — no llama a Firebase
      // Usa el número como verificationId temporal
      await Future.delayed(const Duration(milliseconds: 800));
      codeSent('simulacion_$phoneNumber', null);
      return;
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  // ── Verificar OTP ───────────────────────────────────────────────────────
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    if (kModoSimulacion) {
      if (smsCode != kCodigoPrueba) {
        throw FirebaseAuthException(
          code: 'invalid-verification-code',
          message: 'Código incorrecto. Usa $kCodigoPrueba en modo prueba.',
        );
      }
      // Extrae el número del verificationId simulado
      final phoneNumber = verificationId.replaceFirst('simulacion_', '');
      // Inicia sesión anónima para obtener un uid real
      final credential = await _auth.signInAnonymously();
      return credential;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  // ── Registro: vincula email+pass al usuario y guarda en Firestore ───────
  Future<void> registerUser({
    required String uid,
    required String dni,
    required String nombre,
    required String apellido,
    required String celular,
    required String email,
    required String password,
    required String fechaNacimiento,
  }) async {
    if (!kModoSimulacion) {
      // En producción vincula email+password al usuario de teléfono
      final emailCredential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await _auth.currentUser!.linkWithCredential(emailCredential);
    }

    // Guardar perfil en Firestore (funciona en ambos modos)
    await _db.collection('usuarios').doc(uid).set({
      'uid': uid,
      'dni': dni,
      'nombre': nombre,
      'apellido': apellido,
      'celular': celular,
      'email': email,
      'fechaNacimiento': fechaNacimiento,
      'rol': 'pasajero',
      'bloqueado': false,
      'intentosFallidos': 0,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  // ── Login con celular + contraseña ──────────────────────────────────────
  Future<Map<String, dynamic>> loginWithCelular({
    required String celular,
    required String password,
  }) async {
    try {
      final query = await _db
          .collection('usuarios')
          .where('celular', isEqualTo: celular)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return {'success': false, 'error': 'usuario_no_encontrado'};
      }

      final doc = query.docs.first;
      final data = doc.data();

      if (data['bloqueado'] == true) {
        return {'success': false, 'error': 'cuenta_bloqueada'};
      }

      await _auth.signInWithEmailAndPassword(
        email: data['email'],
        password: password,
      );

      await doc.reference.update({'intentosFallidos': 0});

      return {'success': true};
    } on FirebaseAuthException {
      final query = await _db
          .collection('usuarios')
          .where('celular', isEqualTo: celular)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final intentos = (doc.data()['intentosFallidos'] ?? 0) + 1;
        final bloquear = intentos >= 5;

        await doc.reference.update({
          'intentosFallidos': intentos,
          if (bloquear) 'bloqueado': true,
        });

        if (bloquear) {
          return {'success': false, 'error': 'cuenta_bloqueada'};
        }

        return {
          'success': false,
          'error': 'credenciales_incorrectas',
          'intentosRestantes': 5 - intentos,
        };
      }

      return {'success': false, 'error': 'credenciales_incorrectas'};
    }
  }

  // ── Verificar si celular ya está registrado ─────────────────────────────
  Future<bool> isCelularRegistered(String celular) async {
    final query = await _db
        .collection('usuarios')
        .where('celular', isEqualTo: celular)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // ── Desbloquear cuenta por celular ──────────────────────────────────────
  Future<void> desbloquearCuentaPorCelular(String celular) async {
    final query = await _db
        .collection('usuarios')
        .where('celular', isEqualTo: celular)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({
        'bloqueado': false,
        'intentosFallidos': 0,
      });
    }
  }

  // ── Limpiar sesión huérfana ─────────────────────────────────────────────
  Future<void> limpiarSesionHuerfana() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _db.collection('usuarios').doc(user.uid).get();
      if (!doc.exists) {
        await _auth.signOut();
      }
    }
  }

  // ── Cerrar sesión ───────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
 