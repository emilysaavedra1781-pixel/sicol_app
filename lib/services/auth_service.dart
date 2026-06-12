import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── OTP ─────────────────────────────────────────────────────────────────

  Future<void> sendOTP({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {

await _auth.setSettings(
appVerificationDisabledForTesting: true,
  forceRecaptchaFlow: false,
);

await _auth.verifyPhoneNumber(

      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

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

  // ─── RF01/RF53: Registro ──────────────────────────────────────────────────

  Future<bool> isCelularRegistered(String celular) async {
    final query = await _db
        .collection('usuarios')
        .where('celular', isEqualTo: celular)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<bool> isDniRegistered(String dni) async {
    final query = await _db
        .collection('usuarios')
        .where('dni', isEqualTo: dni)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<bool> isPlacaRegistered(String placa) async {
    final query = await _db
        .collection('usuarios')
        .where('placa', isEqualTo: placa)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<void> registerPasajero({
    required String dni,
    required String nombre,
    required String apellido,
    required String celular,
    required String email,
    required String password,
    required String fechaNacimiento,
  }) async {
    final emailAuth = '$celular@sicol.pe';
    await _auth.createUserWithEmailAndPassword(
      email: emailAuth,
      password: password,
    );
    final uid = _auth.currentUser!.uid;
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
      'bloqueado': false,
      'intentosFallidos': 0,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }
  /// Registro conductor (RF53)
  Future<void> registerConductor({
    required String dni,
    required String nombre,
    required String apellido,
    required String celular,
    required String email,
    required String password,
    required String fechaNacimiento,
    required String numeroLicencia,
    required String placa,
    required String capacidad,
    required String modelo,
    required String marca,
    required String color,
  }) async {
    final emailAuth = '$celular@sicol.pe';
    await _auth.createUserWithEmailAndPassword(
      email: emailAuth,
      password: password,
    );
    final uid = _auth.currentUser!.uid;
    await _db.collection('usuarios').doc(uid).set({
      'uid': uid,
      'dni': dni,
      'nombre': nombre,
      'apellido': apellido,
      'celular': celular,
      'email': email,
      'fechaNacimiento': fechaNacimiento,
      'numeroLicencia': numeroLicencia,
      'rol': 'conductor',
      'estado': 'pendiente',
      'codigoConductor': null,
      'bloqueado': false,
      'intentosFallidos': 0,
      'creadoEn': FieldValue.serverTimestamp(),
      'vehiculo': {
        'placa': placa,
        'capacidad': capacidad,
        'modelo': modelo,
        'marca': marca,
        'color': color,
      },
    });
  }

  // ─── RF02/RF23: Login ─────────────────────────────────────────────────────

  /// Login pasajero con celular + contraseña
  Future<Map<String, dynamic>> loginWithCelular({
    required String celular,
    required String password,
  }) async {
    final query = await _db
        .collection('usuarios')
        .where('celular', isEqualTo: celular)
        .where('rol', isEqualTo: 'pasajero')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return {'success': false, 'error': 'usuario_no_encontrado'};
    }

    final userDoc = query.docs.first;
    final data = userDoc.data();

    if (data['bloqueado'] == true) {
      return {'success': false, 'error': 'cuenta_bloqueada'};
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: data['email'],
        password: password,
      );
      await userDoc.reference.update({'intentosFallidos': 0});
      return {'success': true, 'rol': 'pasajero', 'estado': 'activo'};
    } on FirebaseAuthException {
      final intentos = (data['intentosFallidos'] ?? 0) + 1;
      final Map<String, dynamic> update = {'intentosFallidos': intentos};
      if (intentos >= 3) {
        update['bloqueado'] = true;
        await userDoc.reference.update(update);
        return {'success': false, 'error': 'cuenta_bloqueada'};
      }
      await userDoc.reference.update(update);
      return {
        'success': false,
        'error': 'credenciales_invalidas',
        'intentosRestantes': 3 - intentos,
      };
    }
  }

  /// Login conductor con código de conductor + contraseña (RF23)
  Future<Map<String, dynamic>> loginConductor({
    required String codigoConductor,
    required String password,
  }) async {
    final query = await _db
        .collection('usuarios')
        .where('codigoConductor', isEqualTo: codigoConductor)
        .where('rol', isEqualTo: 'conductor')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return {'success': false, 'error': 'usuario_no_encontrado'};
    }

    final userDoc = query.docs.first;
    final data = userDoc.data();

    if (data['bloqueado'] == true) {
      return {'success': false, 'error': 'cuenta_bloqueada'};
    }

    if (data['estado'] == 'pendiente') {
      return {'success': false, 'error': 'cuenta_pendiente'};
    }

    if (data['estado'] == 'rechazado') {
      return {'success': false, 'error': 'cuenta_rechazada'};
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: data['email'],
        password: password,
      );
      await userDoc.reference.update({'intentosFallidos': 0});
      return {'success': true, 'rol': 'conductor', 'estado': 'activo'};
    } on FirebaseAuthException {
      final intentos = (data['intentosFallidos'] ?? 0) + 1;
      final Map<String, dynamic> update = {'intentosFallidos': intentos};
      if (intentos >= 3) {
        update['bloqueado'] = true;
        await userDoc.reference.update(update);
        return {'success': false, 'error': 'cuenta_bloqueada'};
      }
      await userDoc.reference.update(update);
      return {
        'success': false,
        'error': 'credenciales_invalidas',
        'intentosRestantes': 3 - intentos,
      };
    }
  }

  /// Login admin con celular + contraseña
  Future<Map<String, dynamic>> loginAdmin({
    required String celular,
    required String password,
  }) async {
    final query = await _db
        .collection('admins')
        .where('celular', isEqualTo: celular)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return {'success': false, 'error': 'usuario_no_encontrado'};
    }

    final data = query.docs.first.data();

    if (data['password'] == password) {
      return {'success': true, 'rol': 'admin'};
    }
    return {'success': false, 'error': 'credenciales_invalidas'};
  }

  // ─── RF03/RF46: Recuperación contraseña ──────────────────────────────────

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

  // ─── Admin: gestión de conductores ───────────────────────────────────────

  Stream<QuerySnapshot> getConductoresPendientes() {
    return _db
        .collection('usuarios')
        .where('rol', isEqualTo: 'conductor')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots();
  }

  /// Aprueba conductor y genera código automático
  Future<String> aprobarConductor(String uid) async {
    // Contar conductores aprobados para generar código
    final query = await _db
        .collection('usuarios')
        .where('rol', isEqualTo: 'conductor')
        .where('estado', isEqualTo: 'activo')
        .get();

    final numero = (query.docs.length + 1).toString().padLeft(4, '0');
    final codigo = 'COND-$numero';

    await _db.collection('usuarios').doc(uid).update({
      'estado': 'activo',
      'codigoConductor': codigo,
      'aprobadoEn': FieldValue.serverTimestamp(),
    });

    return codigo;
  }

  Future<void> rechazarConductor(String uid) async {
    await _db.collection('usuarios').doc(uid).update({
      'estado': 'rechazado',
      'rechazadoEn': FieldValue.serverTimestamp(),
    });
  }

  // ─── Perfil ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    return doc.data();
  }

  Future<void> limpiarSesionHuerfana() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _db.collection('usuarios').doc(user.uid).get();
      if (!doc.exists) await _auth.signOut();
    }
  }

  // ─── RF45: Cerrar sesión ──────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}