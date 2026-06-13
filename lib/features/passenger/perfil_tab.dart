import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PerfilTab extends StatelessWidget {
  final String uid;

  const PerfilTab({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    if (uid.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E6BFF)),
      );
    }

    return SafeArea(
      child: FutureBuilder<DocumentSnapshot>(
        future: db.collection('usuarios').doc(uid).get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
          }

          final data = snap.hasData && snap.data!.exists
              ? (snap.data!.data() as Map<String, dynamic>)
              : <String, dynamic>{};

          final nombre = data['nombre'] ?? '';
          final apellido = data['apellido'] ?? '';
          final email = data['email'] ?? '-';
          final foto = data['fotoUrl'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E6BFF), Color(0xFF0A4BCC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          image: foto != null
                              ? DecorationImage(image: NetworkImage(foto), fit: BoxFit.cover)
                              : null,
                        ),
                        child: foto == null
                            ? const Icon(Icons.person_rounded, color: Colors.white, size: 32)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$nombre $apellido'.trim().isEmpty ? 'Pasajero' : '$nombre $apellido',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(email,
                                style: const TextStyle(color: Color(0xFFBFD7FF), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildStatsViajes(uid),
                const SizedBox(height: 20),
                Container(
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
                      const Text('Datos personales',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      _itemPerfil(Icons.person_outline, 'Nombre',
                          '$nombre $apellido'.trim().isEmpty ? '-' : '$nombre $apellido'),
                      _itemPerfil(Icons.email_outlined, 'Email', email),
                      if (data['celular'] != null)
                        _itemPerfil(Icons.phone_outlined, 'Celular', data['celular']),
                      if (data['dni'] != null)
                        _itemPerfil(Icons.badge_outlined, 'DNI', data['dni']),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => auth.signOut(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF3B30),
                      side: const BorderSide(color: Color(0xFFFF3B30), width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Cerrar sesión',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsViajes(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservas')
          .where('pasajeroUid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final todas = snap.data?.docs ?? [];
        final activas = todas.where((d) => (d.data() as Map)['estado'] == 'confirmada').length;
        final completadas = todas.where((d) {
          final e = (d.data() as Map)['estado'];
          return e == 'finalizada' || e == 'completada';
        }).length;
        final canceladas =
            todas.where((d) => (d.data() as Map)['estado'] == 'cancelada').length;

        return Row(
          children: [
            _statCard('Activas', '$activas', const Color(0xFF1E6BFF), Icons.confirmation_number_rounded),
            const SizedBox(width: 10),
            _statCard('Completadas', '$completadas', const Color(0xFF10B981), Icons.check_circle_rounded),
            const SizedBox(width: 10),
            _statCard('Canceladas', '$canceladas', const Color(0xFFFF3B30), Icons.cancel_rounded),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _itemPerfil(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B7280), size: 16),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}