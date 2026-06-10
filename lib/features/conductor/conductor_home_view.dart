// ════════════════════════════════════════════════════════════════════════════
// RF23 — Panel principal del conductor (placeholder)
// Archivo: lib/features/conductor/conductor_home_view.dart
//
// Crea la carpeta: lib/features/conductor/
// y guarda este archivo ahí.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../auth/auth/login/login_view.dart';

class ConductorHomeView extends StatelessWidget {
  final String uid;
  final String nombre;

  const ConductorHomeView({
    super.key,
    required this.uid,
    required this.nombre,
  });

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión',
                style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await AuthService().signOut(); // RF45
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginView()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Text(
          'Hola, $nombre',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF6B7280)),
            tooltip: 'Cerrar sesión',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.drive_eta_rounded,
                color: Color(0xFF10B981), size: 64),
            SizedBox(height: 16),
            Text(
              'Panel del Conductor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Aquí irán las funciones del módulo conductor',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
// ACTUALIZACIÓN: lib/features/auth/login/login_view.dart
//
// En el LoginView del pasajero ya tienes el botón de "Iniciar sesión".
// Agrega debajo del bloque de "¿No tienes cuenta? Regístrate" este widget
// para que el conductor pueda ir a su propio login:
//
// ─────────────────────────────────────────────────────────────────────────
// import '../login/conductor_login_view.dart';   // ← añadir en los imports
//
// // Pega esto al final de la columna en LoginView, después del Row de registro:
// const SizedBox(height: 24),
// const Row(children: [
//   Expanded(child: Divider(color: Color(0xFF1F2937))),
//   Padding(
//     padding: EdgeInsets.symmetric(horizontal: 12),
//     child: Text('o', style: TextStyle(color: Color(0xFF6B7280))),
//   ),
//   Expanded(child: Divider(color: Color(0xFF1F2937))),
// ]),
// const SizedBox(height: 24),
// SizedBox(
//   width: double.infinity,
//   height: 52,
//   child: OutlinedButton.icon(
//     onPressed: () => Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => const ConductorLoginView()),
//     ),
//     icon: const Icon(Icons.drive_eta_rounded,
//         color: Color(0xFF10B981), size: 20),
//     label: const Text(
//       'Soy conductor — Ingresar',
//       style: TextStyle(
//           color: Color(0xFF10B981),
//           fontSize: 15,
//           fontWeight: FontWeight.w600),
//     ),
//     style: OutlinedButton.styleFrom(
//       side: const BorderSide(color: Color(0xFF10B981)),
//       shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(14)),
//     ),
//   ),
// ),
// ════════════════════════════════════════════════════════════════════════════


// ════════════════════════════════════════════════════════════════════════════
// DOCUMENTO FIRESTORE requerido para RF23
//
// Colección: conductores
// Documento de ejemplo para pruebas (créalo manualmente en Firebase Console):
//
// {
//   "codigoConductor": "COND-001",
//   "password": "123456",          ← solo dev/simulación
//   "email": "cond001@sicol.pe",   ← para producción con FirebaseAuth
//   "nombre": "Carlos Quispe",
//   "bloqueado": false,
//   "intentosFallidos": 0,
//   "estado": "activo",            ← "activo" | "inactivo" | "pendiente"
//   "rol": "conductor",
//   "creadoEn": <timestamp>
// }
// ════════════════════════════════════════════════════════════════════════════
