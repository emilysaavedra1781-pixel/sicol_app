import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../shared/mis_incidencias_view.dart';
import '../shared/reportar_incidencia_view.dart';
import '../../widgets/image_picker_widget.dart';
import '../../widgets/logout_helper.dart';
import 'reservas_historial_view.dart';

class PerfilTab extends StatelessWidget {
  final String uid;

  const PerfilTab({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => LogoutHelper.showLogoutDialog(context),
          )
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: db.collection('usuarios').doc(uid).get(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final data = snap.data!.data() as Map<String, dynamic>? ?? {};
          final nombre = data['nombre'] ?? '';
          final apellido = data['apellido'] ?? '';
          final email = data['email'] ?? '-';
          final foto = data['fotoUrl'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      ImagePickerWidget(
                        label: 'FOTO DE PERFIL',
                        initialUrl: foto,
                        storagePath: 'usuarios/$uid/perfil.jpg',
                        onImagenSubida: (url) {
                          FirebaseFirestore.instance.collection('usuarios').doc(uid).update({'fotoUrl': url});
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('$nombre $apellido', style: Theme.of(context).textTheme.titleLarge),
                      Text(email, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildMenuOption(
                          context,
                          Icons.report_problem_outlined,
                          'REPORTAR INCIDENCIA',
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportarIncidenciaView(rolUsuario: 'pasajero', viajeId: ''))),
                        ),
                        const Divider(),
                        _buildMenuOption(
                          context,
                          Icons.history,
                          'MI HISTORIAL DE VIAJES',
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReservasHistorialView(uid: uid))),
                        ),
                        const Divider(),
                        _buildMenuOption(
                          context,
                          Icons.list_alt,
                          'MIS INCIDENCIAS',
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisIncidenciasView())),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow('DNI', data['dni'] ?? '-'),
                        const Divider(),
                        _buildInfoRow('Celular', data['celular'] ?? '-'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuOption(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
