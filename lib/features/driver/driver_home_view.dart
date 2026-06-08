import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../auth/login/login_view.dart';

class DriverHomeView extends StatelessWidget {
  const DriverHomeView({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
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
      await AuthService().signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginView()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('SICOL — Conductor',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout,
                color: Color(0xFF6B7280)),
            tooltip: 'Cerrar sesión',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: uid == null
          ? const Center(
          child: CircularProgressIndicator(
              color: Color(0xFF1E6BFF)))
          : FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF1E6BFF)),
            );
          }

          if (!snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
              child: Text('Error al cargar datos.',
                  style:
                  TextStyle(color: Colors.white)),
            );
          }

          final data = snapshot.data!.data()
          as Map<String, dynamic>;
          final nombre = data['nombre'] ?? '';
          final apellido = data['apellido'] ?? '';
          final codigo =
              data['codigoConductor'] ?? '-';
          final vehiculo =
              data['vehiculo'] as Map<String, dynamic>? ??
                  {};

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 32),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                // Bienvenida
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1E6BFF),
                        Color(0xFF0A4BCC),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Icon(
                          Icons.drive_eta_rounded,
                          color: Colors.white,
                          size: 40),
                      const SizedBox(height: 12),
                      Text(
                        '¡Bienvenido, $nombre!',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight:
                            FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Panel del conductor',
                        style: TextStyle(
                            color: Color(0xFFBFD7FF),
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Código de conductor
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius:
                    BorderRadius.circular(16),
                    border: Border.all(
                        color:
                        const Color(0xFF1F2937)),
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu código de conductor',
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        codigo,
                        style: const TextStyle(
                          color: Color(0xFF1E6BFF),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Guarda este código para iniciar sesión.',
                        style: TextStyle(
                            color: Color(0xFF4B5563),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Info personal
                _infoCard(
                  titulo: 'Datos personales',
                  items: [
                    _InfoItem(
                        Icons.person_outline,
                        'Nombre',
                        '$nombre $apellido'),
                    _InfoItem(Icons.badge_outlined,
                        'DNI', data['dni'] ?? '-'),
                    _InfoItem(Icons.phone_outlined,
                        'Celular',
                        data['celular'] ?? '-'),
                    _InfoItem(
                        Icons.card_membership_outlined,
                        'Licencia',
                        data['numeroLicencia'] ?? '-'),
                  ],
                ),
                const SizedBox(height: 16),

                // Info vehículo
                _infoCard(
                  titulo: 'Mi vehículo',
                  items: [
                    _InfoItem(
                        Icons.directions_car_outlined,
                        'Placa',
                        vehiculo['placa'] ?? '-'),
                    _InfoItem(
                        Icons.directions_car_outlined,
                        'Vehículo',
                        '${vehiculo['marca'] ?? ''} ${vehiculo['modelo'] ?? ''}'),
                    _InfoItem(
                        Icons.color_lens_outlined,
                        'Color',
                        vehiculo['color'] ?? '-'),
                    _InfoItem(
                        Icons.people_outline,
                        'Capacidad',
                        '${vehiculo['capacidad'] ?? '-'} pasajeros'),
                  ],
                ),
                const SizedBox(height: 32),

                // Placeholder panel
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius:
                    BorderRadius.circular(16),
                    border: Border.all(
                        color:
                        const Color(0xFF1F2937)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.construction_rounded,
                          color: Color(0xFF6B7280),
                          size: 40),
                      SizedBox(height: 12),
                      Text(
                        'Módulo de viajes próximamente',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight:
                            FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Aquí irán las funciones de gestión de viajes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoCard(
      {required String titulo,
        required List<_InfoItem> items}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(item.icon,
                    color: const Color(0xFF6B7280),
                    size: 16),
                const SizedBox(width: 10),
                Text('${item.label}: ',
                    style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13)),
                Expanded(
                  child: Text(item.value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem(this.icon, this.label, this.value);
}