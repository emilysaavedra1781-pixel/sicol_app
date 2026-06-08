import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../auth/login/login_view.dart';

class AdminHomeView extends StatefulWidget {
  const AdminHomeView({super.key});

  @override
  State<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<AdminHomeView>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
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

    if (confirm == true && mounted) {
      await _authService.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginView()),
            (route) => false,
      );
    }
  }

  Future<void> _aprobar(String uid, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Aprobar conductor',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Aprobar la cuenta de $nombre? Se generará su código de conductor automáticamente.',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aprobar',
                style: TextStyle(color: Color(0xFF10B981))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final codigo = await _authService.aprobarConductor(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ $nombre aprobado. Código: $codigo'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _rechazar(String uid, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Rechazar conductor',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Rechazar la cuenta de $nombre? Esta acción no se puede deshacer.',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar',
                style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.rechazarConductor(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Cuenta de $nombre rechazada.'),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
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
        title: const Text('SICOL — Administrador',
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1E6BFF),
          labelColor: const Color(0xFF1E6BFF),
          unselectedLabelColor: const Color(0xFF6B7280),
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Aprobados'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendientes(),
          _buildAprobados(),
        ],
      ),
    );
  }

  Widget _buildPendientes() {
    return StreamBuilder<QuerySnapshot>(
      stream: _authService.getConductoresPendientes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF1E6BFF)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    color: Color(0xFF10B981), size: 64),
                SizedBox(height: 16),
                Text('No hay conductores pendientes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('Todos los conductores han sido revisados.',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data =
            docs[index].data() as Map<String, dynamic>;
            final uid = docs[index].id;
            return _conductorCard(data, uid,
                pendiente: true);
          },
        );
      },
    );
  }

  Widget _buildAprobados() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'conductor')
          .where('estado', isEqualTo: 'activo')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF1E6BFF)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.drive_eta_outlined,
                    color: Color(0xFF6B7280), size: 64),
                SizedBox(height: 16),
                Text('No hay conductores aprobados',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data =
            docs[index].data() as Map<String, dynamic>;
            final uid = docs[index].id;
            return _conductorCard(data, uid,
                pendiente: false);
          },
        );
      },
    );
  }

  Widget _conductorCard(Map<String, dynamic> data, String uid,
      {required bool pendiente}) {
    final nombre = data['nombre'] ?? '';
    final apellido = data['apellido'] ?? '';
    final vehiculo =
        data['vehiculo'] as Map<String, dynamic>? ?? {};
    final codigo = data['codigoConductor'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pendiente
                  ? const Color(0xFFF59E0B).withOpacity(0.08)
                  : const Color(0xFF10B981).withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: pendiente
                        ? const Color(0xFFF59E0B)
                        .withOpacity(0.2)
                        : const Color(0xFF10B981)
                        .withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person,
                      color: pendiente
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                      size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text('$nombre $apellido',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      Text(
                        pendiente
                            ? 'Pendiente de aprobación'
                            : 'Código: ${codigo ?? '-'}',
                        style: TextStyle(
                            color: pendiente
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(Icons.badge_outlined, 'DNI',
                    data['dni'] ?? '-'),
                _infoRow(Icons.phone_outlined, 'Celular',
                    data['celular'] ?? '-'),
                _infoRow(
                    Icons.card_membership_outlined,
                    'Licencia',
                    data['numeroLicencia'] ?? '-'),
                _infoRow(
                    Icons.directions_car_outlined,
                    'Placa',
                    vehiculo['placa'] ?? '-'),
                _infoRow(
                    Icons.directions_car_outlined,
                    'Vehículo',
                    '${vehiculo['marca'] ?? ''} ${vehiculo['modelo'] ?? ''}'),
                _infoRow(Icons.people_outline, 'Capacidad',
                    '${vehiculo['capacidad'] ?? '-'} pasajeros'),
              ],
            ),
          ),

          // Botones solo en pendientes
          if (pendiente)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _rechazar(uid, '$nombre $apellido'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                        const Color(0xFFFF3B30),
                        side: const BorderSide(
                            color: Color(0xFFFF3B30)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                      ),
                      child: const Text('Rechazar',
                          style: TextStyle(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _aprobar(uid, '$nombre $apellido'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                      ),
                      child: const Text('Aprobar',
                          style: TextStyle(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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