import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/login/login_view.dart';

class PassengerHomeView extends StatelessWidget {
  const PassengerHomeView({super.key});

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
        title: const Text(
          'SICOL — Pasajero',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
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
            Icon(Icons.directions_bus_rounded,
                color: Color(0xFF1E6BFF), size: 64),
            SizedBox(height: 16),
            Text(
              'Panel del Pasajero',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Aquí irán las funciones del módulo de pasajero',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
