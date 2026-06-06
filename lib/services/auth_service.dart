import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int maxFailedAttempts = 3;

  // ─── RF01: Registro de Usuario ───────────────────────────────────────────

  /// Verifica si el celular ya está registrado en Firestore
  Future<bool> isCelularRegistered(String celular) async {
    final query = await _db
        .collection('usuarios')
        .where('celular', isEqualTo: celular)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Envía OTP al número de celular (Firebase Phone Auth)
  Future<void> sendOTP({
    required String phoneNumber, // formato: +51XXXXXXXXX
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  /// Verifica el OTP ingresado por el usuario
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  /// Registra al usuario en Firestore después de verificar OTP (RF01)
  Future<void> registerUser({
    required String uid,
    required String dni,
    required String nombre,
    required String apellido,
    required String celular,
    required String fechaNacimiento,
    required String email,
  }) async {
    await _db.collection('usuarios').doc(uid).set({
      'uid': uid,
      'dni': dni,
      'nombre': nombre,
      'apellido': apellido,
      'celular': celular,
      'email': email,
      'fechaNacimiento': fechaNacimiento,
      'rol': 'pasajero',
      'estado': 'activo',
      'intentosFallidos': 0,
      'bloqueado': false,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  // ─── RF02: Inicio de Sesión ───────────────────────────────────────────────

  /// Login con email/password. Maneja bloqueo por intentos fallidos (RF40)
  Future<Map<String, dynamic>> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    // Buscar usuario por email en Firestore para verificar bloqueo
    final query = await _db
        .collection('usuarios')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return {'success': false, 'error': 'usuario_no_encontrado'};
    }

    final userDoc = query.docs.first;
    final data = userDoc.data();

    // RF40: Verificar si está bloqueado
    if (data['bloqueado'] == true) {
      return {'success': false, 'error': 'cuenta_bloqueada'};
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Resetear intentos fallidos al login exitoso
      await userDoc.reference.update({'intentosFallidos': 0});

      return {'success': true, 'user': credential.user};
    } on FirebaseAuthException {
      // Incrementar intentos fallidos
      final intentos = (data['intentosFallidos'] ?? 0) + 1;
      final Map<String, dynamic> update = {'intentosFallidos': intentos};

      // RF40: Bloquear tras 3 intentos
      if (intentos >= maxFailedAttempts) {
        update['bloqueado'] = true;
        await userDoc.reference.update(update);
        return {'success': false, 'error': 'cuenta_bloqueada'};
      }

      await userDoc.reference.update(update);
      return {
        'success': false,
        'error': 'credenciales_invalidas',
        'intentosRestantes': maxFailedAttempts - intentos,
      };
    }
  }

  // ─── RF03: Recuperación de Contraseña ────────────────────────────────────

  // ─── RF03: Recuperación de Contraseña ────────────────────────────────────

  /// Verifica OTP y permite cambiar contraseña (RF03)
  /// El envío de OTP ya usa sendOTP() que está en RF01

  /// Desbloquea cuenta por celular (RF40 - usado en recuperación)
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

  // ─── RF04: Gestión de Perfil ──────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    return doc.data();
  }

  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection('usuarios').doc(uid).update({
      ...data,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // ─── RF45: Cierre de Sesión ───────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}