import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../auth/login/login_view.dart';
import 'driver_home_view.dart';
import '../../app_theme.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Estado de Cuenta', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: CabifyColors.primary),
            onPressed: _logout,
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator(color: CabifyColors.primary))
          : StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: CabifyColors.primary));
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text('Error al cargar datos.', style: TextStyle(color: CabifyColors.textPrimary)));

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final estado = data['estado'] ?? 'pendiente';

          if (estado == 'activo' && data['codigoConductor'] != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DriverHomeView()), (route) => false);
            });
          }

          if (estado == 'rechazado') return _buildRechazado();
          return _buildPendiente(data);
        },
      ),
    );
  }

  Widget _buildPendiente(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            child: const Icon(Icons.hourglass_empty_rounded, color: Color(0xFFF59E0B), size: 50),
          ),
          const SizedBox(height: 24),
          Text('En revisión', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: CabifyColors.textPrimary)),
          const SizedBox(height: 12),
          const Text(
            'Tu solicitud está siendo revisada por el administrador. Te notificaremos cuando sea aprobada.',
            textAlign: TextAlign.center,
            style: TextStyle(color: CabifyColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 40),
          Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: CabifyColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Datos registrados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: CabifyColors.textPrimary)),
                  const Divider(height: 32, color: CabifyColors.border),
                  _infoRow('Nombre', '${data['nombre']} ${data['apellido']}'),
                  _infoRow('Placa', data['vehiculo']?['placa'] ?? '-'),
                  _infoRow('Vehículo', '${data['vehiculo']?['marca']} ${data['vehiculo']?['modelo']}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRechazado() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: CabifyColors.error.withValues(alpha: 0.1),
            child: const Icon(Icons.cancel_outlined, color: CabifyColors.error, size: 50),
          ),
          const SizedBox(height: 24),
          const Text('Solicitud rechazada', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: CabifyColors.textPrimary)),
          const SizedBox(height: 16),
          const Text(
            'Tu solicitud no pudo ser aprobada en este momento. Contacta a soporte para más detalles.',
            textAlign: TextAlign.center,
            style: TextStyle(color: CabifyColors.textSecondary),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.error),
            child: const Text('VOLVER AL INICIO', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: CabifyColors.textPrimary)),
        ],
      ),
    );
  }
}
