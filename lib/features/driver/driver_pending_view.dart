import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../auth/login/login_view.dart';
import 'driver_home_view.dart';

class DriverPendingView extends StatefulWidget {
  const DriverPendingView({super.key});

  @override
  State<DriverPendingView> createState() => _DriverPendingViewState();
}

class _DriverPendingViewState extends State<DriverPendingView> {
  final _authService = AuthService();

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
          (route) => false,
    );
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
            onPressed: _logout,
          ),
        ],
      ),
      body: uid == null
          ? const Center(
          child: CircularProgressIndicator(
              color: Color(0xFF1E6BFF)))
          : StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .snapshots(),
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
          final estado = data['estado'] ?? 'pendiente';
          final codigoConductor =
          data['codigoConductor'];

          // Si ya fue aprobado → ir a DriverHomeView
          if (estado == 'activo' &&
              codigoConductor != null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                    const DriverHomeView()),
                    (route) => false,
              );
            });
          }

          // Si fue rechazado
          if (estado == 'rechazado') {
            return _buildRechazado();
          }

          // Pendiente — mostrar código si ya fue aprobado
          return _buildPendiente(
              estado, codigoConductor, data);
        },
      ),
    );
  }

  Widget _buildPendiente(String estado,
      String? codigoConductor, Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding:
      const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Ícono estado
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_empty_rounded,
                color: Color(0xFFF59E0B), size: 50),
          ),
          const SizedBox(height: 24),

          const Text('Cuenta en revisión',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text(
            'Tu solicitud está siendo revisada por el administrador. Te notificaremos cuando sea aprobada.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                height: 1.6),
          ),
          const SizedBox(height: 32),

          // Datos del conductor
          _infoCard(data),
          const SizedBox(height: 24),

          // Instrucción
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E6BFF).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color:
                  const Color(0xFF1E6BFF).withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: Color(0xFF1E6BFF), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Una vez aprobada tu cuenta, aquí aparecerá tu código de conductor para iniciar sesión.',
                    style: TextStyle(
                        color: Color(0xFF93C5FD),
                        fontSize: 13,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRechazado() {
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cancel_outlined,
                color: Color(0xFFFF3B30), size: 50),
          ),
          const SizedBox(height: 24),
          const Text('Cuenta rechazada',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text(
            'Tu solicitud fue rechazada por el administrador. Contacta al soporte para más información.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                height: 1.6),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Volver al inicio',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(Map<String, dynamic> data) {
    final vehiculo =
        data['vehiculo'] as Map<String, dynamic>? ?? {};
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
          const Text('Tus datos registrados',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _infoRow(Icons.person_outline, 'Nombre',
              '${data['nombre']} ${data['apellido']}'),
          _infoRow(Icons.badge_outlined, 'DNI', data['dni']),
          _infoRow(Icons.phone_outlined, 'Celular',
              data['celular']),
          _infoRow(Icons.card_membership_outlined, 'Licencia',
              data['numeroLicencia'] ?? '-'),
          const Divider(color: Color(0xFF1F2937), height: 24),
          const Text('Vehículo',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          _infoRow(Icons.directions_car_outlined, 'Placa',
              vehiculo['placa'] ?? '-'),
          _infoRow(Icons.directions_car_outlined, 'Vehículo',
              '${vehiculo['marca']} ${vehiculo['modelo']}'),
          _infoRow(Icons.color_lens_outlined, 'Color',
              vehiculo['color'] ?? '-'),
          _infoRow(Icons.people_outline, 'Capacidad',
              '${vehiculo['capacidad']} pasajeros'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B7280), size: 16),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}