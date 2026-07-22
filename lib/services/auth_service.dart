import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';


class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

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

  Future<Map<String, dynamic>> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return {'success': true, 'user': userCredential.user};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _handleOtpError(e.code)};
    } catch (e) {
      return {'success': false, 'error': 'unknown-error'};
    }
  }

  String _handleOtpError(String code) {
    switch (code) {
      case 'invalid-verification-code': return 'invalid-otp';
      case 'session-expired': return 'expired-otp';
      case 'network-request-failed': return 'network-error';
      default: return code;
    }
  }

  // ─── RF01/RF53: Registro ──────────────────────────────────────────────────

  Future<bool> isCelularRegistered(String celular, {String? excludeUid}) async {
    var query = _db.collection('usuarios').where('celular', isEqualTo: celular);
    final result = await query.limit(5).get();
    if (excludeUid == null) return result.docs.isNotEmpty;
    return result.docs.any((doc) => doc.id != excludeUid);
  }

  Future<bool> isDniRegistered(String dni, {String? excludeUid}) async {
    var query = _db.collection('usuarios').where('dni', isEqualTo: dni);
    final result = await query.limit(5).get();
    if (excludeUid == null) return result.docs.isNotEmpty;
    return result.docs.any((doc) => doc.id != excludeUid);
  }

  Future<bool> isPlacaRegistered(String placa, {String? excludeUid}) async {
    var query = _db.collection('usuarios').where('vehiculo.placa', isEqualTo: placa);
    final result = await query.limit(5).get();
    if (excludeUid == null) return result.docs.isNotEmpty;
    return result.docs.any((doc) => doc.id != excludeUid);
  }

  Future<Map<String, dynamic>> registerPasajero({
    required String dni,
    required String nombre,
    required String apellido,
    required String celular,
    required String email,
    required String password,
    required String fechaNacimiento,
  }) async {
    try {
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
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _handleAuthError(e.code)};
    } catch (e) {
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        return {'success': false, 'error': 'network-error'};
      }
      return {'success': false, 'error': 'unknown-error'};
    }
  }

  String _handleAuthError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'duplicate-phone';
      case 'weak-password': return 'weak-password';
      case 'network-request-failed': return 'network-error';
      default: return code;
    }
  }
  Future<String?> uploadImage(File image, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> registerConductor({
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
    File? fotoPerfil,
    File? fotoVehiculo,
    File? pdfDni,
    File? pdfLicencia,
    File? pdfTarjeta,
  }) async {
    try {
      final emailAuth = '$celular@sicol.pe';
      await _auth.createUserWithEmailAndPassword(
        email: emailAuth,
        password: password,
      );
      final uid = _auth.currentUser!.uid;

      String? fotoUrl;
      if (fotoPerfil != null) {
        fotoUrl = await uploadImage(fotoPerfil, 'usuarios/$uid/perfil.jpg');
      }

      String? fotoVehiculoUrl;
      if (fotoVehiculo != null) {
        fotoVehiculoUrl = await uploadImage(fotoVehiculo, 'usuarios/$uid/vehiculo.jpg');
      }

      // Subida de PDFs
      String? dniUrl;
      if (pdfDni != null) {
        dniUrl = await uploadImage(pdfDni, 'documentos/conductores/$uid/dni.pdf');
      }

      String? licenciaUrl;
      if (pdfLicencia != null) {
        licenciaUrl = await uploadImage(pdfLicencia, 'documentos/conductores/$uid/licencia.pdf');
      }

      String? tarjetaUrl;
      if (pdfTarjeta != null) {
        tarjetaUrl = await uploadImage(pdfTarjeta, 'documentos/conductores/$uid/tarjeta_propiedad.pdf');
      }

      await _db.collection('usuarios').doc(uid).set({
        'uid': uid,
        'dni': dni,
        'nombre': nombre,
        'apellido': apellido,
        'celular': celular,
        'email': email,
        'fotoUrl': fotoUrl,
        'fechaNacimiento': fechaNacimiento,
        'numeroLicencia': numeroLicencia,
        'rol': 'conductor',
        'estado': 'pendiente_aprobacion',
        'codigoConductor': null,
        'bloqueado': false,
        'intentosFallidos': 0,
        'creadoEn': FieldValue.serverTimestamp(),
        'documentos': {
          'dni': {'url': dniUrl, 'estado': 'pendiente'},
          'licencia': {'url': licenciaUrl, 'estado': 'pendiente'},
          'tarjeta_propiedad': {'url': tarjetaUrl, 'estado': 'pendiente'},
        },
        'vehiculo': {
          'placa': placa,
          'capacidad': capacidad,
          'modelo': modelo,
          'marca': marca,
          'color': color,
          'fotoVehiculoUrl': fotoVehiculoUrl,
          'estado': 'pendiente',
          'fechaRegistro': FieldValue.serverTimestamp(),
        },
      });
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _handleAuthError(e.code)};
    } catch (e) {
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        return {'success': false, 'error': 'network-error'};
      }
      return {'success': false, 'error': 'unknown-error'};
    }
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

    if (data['bloqueado'] == true || data['estado'] == 'bloqueado') {
      return {'success': false, 'error': 'cuenta_bloqueada'};
    }

    try {
      final emailAuth = '$celular@sicol.pe';
      await _auth.signInWithEmailAndPassword(
        email: emailAuth,
        password: password,
      );
      await userDoc.reference.update({'intentosFallidos': 0});
      return {'success': true, 'rol': 'pasajero', 'estado': 'activo'};
    } on FirebaseAuthException {
      final intentos = (data['intentosFallidos'] ?? 0) + 1;
      final Map<String, dynamic> update = {'intentosFallidos': intentos};
      
      if (intentos >= 3) {
        update['bloqueado'] = true;
        update['estado'] = 'bloqueado'; // CP01
        update['intentosFallidos'] = 0; // CP01: Resetear tras bloquear
        await userDoc.reference.update(update);
        return {'success': false, 'error': 'cuenta_bloqueada'};
      }

      await userDoc.reference.update(update);
      return {
        'success': false,
        'error': 'credenciales_invalidas',
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

    if (data['bloqueado'] == true || data['estado'] == 'bloqueado') {
      return {'success': false, 'error': 'cuenta_bloqueada'};
    }

    if (data['estado'] == 'pendiente' || data['estado'] == 'pendiente_aprobacion') {
      return {'success': false, 'error': 'cuenta_pendiente'};
    }

    if (data['estado'] == 'rechazado') {
      return {'success': false, 'error': 'cuenta_rechazada'};
    }

    try {
      final celular = data['celular'];
      final emailAuth = '$celular@sicol.pe';
      await _auth.signInWithEmailAndPassword(
        email: emailAuth,
        password: password,
      );
      await userDoc.reference.update({'intentosFallidos': 0});
      return {'success': true, 'rol': 'conductor', 'estado': 'activo'};
    } on FirebaseAuthException {
      final intentos = (data['intentosFallidos'] ?? 0) + 1;
      final Map<String, dynamic> update = {'intentosFallidos': intentos};
      
      if (intentos >= 3) {
        update['bloqueado'] = true;
        update['estado'] = 'bloqueado'; // CP01
        update['intentosFallidos'] = 0; // CP01: Resetear tras bloquear
        await userDoc.reference.update(update);
        return {'success': false, 'error': 'cuenta_bloqueada'};
      }

      await userDoc.reference.update(update);
      return {
        'success': false,
        'error': 'credenciales_invalidas',
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
    final email = data['email'];

    if (email == null) {
      // Si no tiene email, usamos la validación por campo password (legacy/pruebas)
      if (data['password'] == password) {
        return {'success': true, 'rol': 'admin'};
      }
      return {'success': false, 'error': 'credenciales_invalidas'};
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return {'success': true, 'rol': 'admin'};
    } on FirebaseAuthException {
      return {'success': false, 'error': 'credenciales_invalidas'};
    }
  }

  // ─── RF03/RF46: Recuperación contraseña ──────────────────────────────────

  /// Solicita el envío de un OTP de recuperación al email asociado al DNI/celular.
  Future<Map<String, dynamic>> solicitarOtpRecuperacion(String email) async {
    try {
      final result = await _functions.httpsCallable('solicitarOtpRecuperacion').call({
        'email': email,
      });
      return {'success': result.data['success'] == true};
    } on FirebaseFunctionsException catch (e) {
      return {'success': false, 'error': e.code == 'not-found' ? 'usuario_no_encontrado' : e.message};
    } catch (e) {
      return {'success': false, 'error': 'network-error'};
    }
  }

  /// Verifica el OTP de recuperación ingresado por el usuario.
  Future<Map<String, dynamic>> verificarOtpRecuperacion(String email, String otp) async {
    try {
      final result = await _functions.httpsCallable('verificarOtpRecuperacion').call({
        'email': email,
        'otp': otp,
      });
      return {
        'success': result.data['success'] == true,
        'uid': result.data['uid'],
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false, 
        'error': e.code == 'deadline-exceeded' ? 'expired-otp' : (e.code == 'permission-denied' ? 'too-many-attempts' : 'invalid-otp')
      };
    } catch (e) {
      return {'success': false, 'error': 'network-error'};
    }
  }

  /// Cambia la contraseña usando el flujo seguro de OTP.
  /// RF46 CP07: El backend desbloquea la cuenta automáticamente.
  Future<Map<String, dynamic>> cambiarPasswordSeguro(String uid, String newPassword) async {
    try {
      final result = await _functions.httpsCallable('changePasswordSecure').call({
        'uid': uid,
        'newPassword': newPassword,
      });
      return {'success': result.data['success'] == true};
    } on FirebaseFunctionsException catch (e) {
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {'success': false, 'error': 'network-error'};
    }
  }

  Future<void> desbloquearCuentaPorCelular(String celular) async {
    final query = await _db
        .collection('usuarios')
        .where('celular', isEqualTo: celular)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({
        'estado': 'activo',
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
        .where('estado', whereIn: ['pendiente', 'pendiente_aprobacion'])
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

  /// RF26 CP04, CP05: Cambia el estado manual de un conductor (Activo/Inactivo)
  Future<void> cambiarEstadoConductor(String uid, String nuevoEstado) async {
    await _db.collection('usuarios').doc(uid).update({
      'estado': nuevoEstado,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// RF26 CP03: Actualiza datos genéricos del conductor
  Future<void> actualizarDatosConductor(String uid, Map<String, dynamic> data) async {
    await _db.collection('usuarios').doc(uid).update({
      ...data,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMpCollectorId(String uid, String collectorId) async {
    await _db.collection('usuarios').doc(uid).update({
      'mp_collector_id': collectorId,
    });
  }

  // ─── Perfil ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    return doc.data();
  }

  Future<String> obtenerUidPorCelular(String celular) async {
    final query = await _db
        .collection('usuarios')
        .where('celular', isEqualTo: celular)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Usuario no encontrado');
    }

    return query.docs.first.id;
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


