// ════════════════════════════════════════════════════════════════════════════
// RF23 — Inicio de Sesión del Conductor
// INSTRUCCIÓN: Copia este método DENTRO de la clase AuthService en
//              lib/services/auth_service.dart
// ════════════════════════════════════════════════════════════════════════════

  /// RF23 · Login del conductor con código de conductor + contraseña
  ///
  /// Colección Firestore: 'conductores'
  /// Campos requeridos en cada doc:
  ///   - codigoConductor  (String)
  ///   - password         (String, hash o texto plano en dev)
  ///   - bloqueado        (bool)
  ///   - intentosFallidos (int)
  ///   - estado           (String: 'activo' | 'inactivo' | 'pendiente')
  ///   - nombre           (String)
  ///
  /// Retorna un Map con:
  ///   { success: true,  uid: '...',  nombre: '...' }
  ///   { success: false, error: 'cuenta_bloqueada' }
  ///   { success: false, error: 'cuenta_inactiva' }
  ///   { success: false, error: 'conductor_no_encontrado' }
  ///   { success: false, error: 'credenciales_incorrectas',
  ///                     intentosRestantes: N }
  Future<Map<String, dynamic>> loginConductor({
    required String codigoConductor,
    required String password,
  }) async {
    try {
      // 1. Buscar conductor por código
      final query = await _db
          .collection('conductores')
          .where('codigoConductor', isEqualTo: codigoConductor.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return {'success': false, 'error': 'conductor_no_encontrado'};
      }

      final doc  = query.docs.first;
      final data = doc.data();

      // 2. Cuenta bloqueada (RF40)
      if (data['bloqueado'] == true) {
        return {'success': false, 'error': 'cuenta_bloqueada'};
      }

      // 3. Cuenta inactiva / pendiente de aprobación (RF53 / RF26)
      final estado = data['estado'] ?? 'inactivo';
      if (estado != 'activo') {
        return {'success': false, 'error': 'cuenta_inactiva'};
      }

      // 4. Verificar contraseña
      //    • En producción usa firebase_auth signInWithEmailAndPassword
      //      igual que loginWithCelular del pasajero.
      //    • En modo simulación comparamos directo (dev only).
      bool passwordOk = false;

      if (kModoSimulacion) {
        passwordOk = data['password'] == password;
      } else {
        try {
          await _auth.signInWithEmailAndPassword(
            email: data['email'] as String,
            password: password,
          );
          passwordOk = true;
        } on FirebaseAuthException {
          passwordOk = false;
        }
      }

      if (passwordOk) {
        // 5. Éxito: resetear intentos
        await doc.reference.update({'intentosFallidos': 0});
        return {
          'success': true,
          'uid': doc.id,
          'nombre': data['nombre'] ?? '',
        };
      }

      // 6. Contraseña incorrecta: incrementar intentos (bloqueo en 3 — RF40)
      final intentos = (data['intentosFallidos'] ?? 0) + 1;
      final bloquear = intentos >= 3;

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
        'intentosRestantes': 3 - intentos,
      };
    } catch (e) {
      return {'success': false, 'error': 'error_servidor'};
    }
  }
