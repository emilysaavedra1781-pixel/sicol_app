class ValidationService {
  /// Valida que un DNI tenga 8 dígitos
  static String? validarDni(String? v) {
    if (v == null || v.isEmpty) return 'El DNI es requerido';
    if (v.length != 8 || !RegExp(r'^\d+$').hasMatch(v)) {
      return 'El DNI debe tener 8 dígitos';
    }
    return null;
  }

  /// Valida que un celular tenga 9 dígitos y empiece con 9
  static String? validarCelular(String? v) {
    if (v == null || v.isEmpty) return 'El celular es requerido';
    final clean = v.replaceAll(' ', '').replaceAll('-', '');
    if (clean.length != 9 || !clean.startsWith('9') || !RegExp(r'^\d+$').hasMatch(clean)) {
      return '9 dígitos (Ej. 9XXXXXXXX)';
    }
    return null;
  }

  /// Valida formato de email básico
  static String? validarEmail(String? v) {
    if (v == null || v.isEmpty) return 'El email es requerido';
    if (!v.contains('@') || !v.contains('.')) {
      return 'Email inválido';
    }
    return null;
  }

  /// Valida longitud de contraseña
  static String? validarPassword(String? v) {
    if (v == null || v.length < 8) {
      return 'Mínimo 8 caracteres';
    }
    return null;
  }

  /// Valida campos requeridos genéricos
  static String? validarRequerido(String? v, String campo) {
    if (v == null || v.trim().isEmpty) {
      return '$campo es requerido';
    }
    return null;
  }

  /// Valida formato de licencia de conducir (Ej. Q12345678)
  static String? validarLicencia(String? v) {
    if (v == null || v.isEmpty) return 'Requerido';
    if (!RegExp(r'^[A-Z]\d{8}$').hasMatch(v)) {
      return 'Formato inválido (Ej. Q12345678)';
    }
    return null;
  }

  /// Valida los datos de un viajero
  /// RF50 CP02
  static bool esViajeroValido(String? nombre, String? dni) {
    return (nombre != null && nombre.isNotEmpty) && (dni != null && dni.length == 8);
  }

  /// Valida la presencia de documentos obligatorios del conductor
  /// RF53 CP02, CP05
  static String? validarDocumentosConductor({
    required dynamic foto,
    required dynamic dni,
    required dynamic licencia,
    required dynamic tarjeta,
  }) {
    if (foto == null) return 'La fotografía es obligatoria';
    if (dni == null || licencia == null || tarjeta == null) {
      return 'Debes subir todos los documentos requeridos (PDF)';
    }
    return null;
  }
}
