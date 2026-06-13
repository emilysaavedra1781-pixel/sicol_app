// lib/models/user_model.dart
// RF01, RF02, RF23, RF40 — Modelo de datos del usuario
// Autor: Samuel Torres Ayala

class UserModel {
  final String uid;
  final String phone;
  final String role;
  final String nombre;
  final String apellido;
  final String dni;
  final String estado;
  final int loginAttempts;
  final bool isBlocked;

  UserModel({
    required this.uid,
    required this.phone,
    required this.role,
    this.nombre = '',
    this.apellido = '',
    this.dni = '',
    this.estado = 'activo',
    this.loginAttempts = 0,
    this.isBlocked = false,
  });

  /// Convierte un documento Firestore en UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      phone: map['celular'] ?? map['phone'] ?? '',
      role: map['rol'] ?? map['role'] ?? '',
      nombre: map['nombre'] ?? '',
      apellido: map['apellido'] ?? '',
      dni: map['dni'] ?? '',
      estado: map['estado'] ?? 'activo',
      loginAttempts: map['intentosFallidos'] ?? map['loginAttempts'] ?? 0,
      isBlocked: map['bloqueado'] ?? map['isBlocked'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'celular': phone,
      'rol': role,
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'estado': estado,
      'intentosFallidos': loginAttempts,
      'bloqueado': isBlocked,
    };
  }

  /// Retorna true si la cuenta está activa y no bloqueada
  bool get puedeIniciarSesion => !isBlocked && estado == 'activo';
}


