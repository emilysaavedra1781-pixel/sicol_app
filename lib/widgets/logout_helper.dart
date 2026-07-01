import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/login/login_view.dart';
import '../app_theme.dart';

class LogoutHelper {
  static Future<void> showLogoutDialog(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Cerrar sesión?',
          style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Estás seguro que deseas cerrar sesión?',
          style: TextStyle(color: CabifyColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR', style: TextStyle(color: CabifyColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CabifyColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              minimumSize: const Size(100, 40),
            ),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // CP01: Ejecutar Firebase Auth signOut
      await FirebaseAuth.instance.signOut();

      // CP01 & CP03: Limpiar todos los datos de sesión del dispositivo
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (context.mounted) {
        // Redirigir inmediatamente a la pantalla de login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginView()),
          (route) => false,
        );
      }
    }
  }
}
