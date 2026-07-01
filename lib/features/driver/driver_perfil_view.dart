import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/image_picker_widget.dart';
import '../../app_theme.dart';

class DriverPerfilView extends StatefulWidget {
  const DriverPerfilView({super.key});

  @override
  State<DriverPerfilView> createState() => _DriverPerfilViewState();
}

class _DriverPerfilViewState extends State<DriverPerfilView> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Sesión no iniciada')));

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil de Conductor')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('usuarios').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final vehiculo = data['vehiculo'] as Map<String, dynamic>? ?? {};
          final documentos = data['documentos'] as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ImagePickerWidget(
                  label: 'FOTO DE PERFIL',
                  initialUrl: data['fotoUrl'],
                  storagePath: 'usuarios/$uid/perfil.jpg',
                  onImagenSubida: (url) => _updateField('fotoUrl', url),
                ),
                const SizedBox(height: 32),
                
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('MI VEHÍCULO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6B7280))),
                ),
                const SizedBox(height: 16),
                ImagePickerWidget(
                  label: 'FOTO DEL AUTO',
                  initialUrl: vehiculo['fotoVehiculoUrl'],
                  storagePath: 'conductores/$uid/vehiculo.jpg',
                  onImagenSubida: (url) => _updateNestedField('vehiculo', 'fotoVehiculoUrl', url),
                ),
                
                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('MIS DOCUMENTOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6B7280))),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDocItem('DNI', documentos['dni_url'], 'conductores/$uid/documentos/dni.jpg', 'dni_url'),
                        const Divider(),
                        _buildDocItem('Licencia', documentos['licencia_url'], 'conductores/$uid/documentos/licencia.jpg', 'licencia_url'),
                        const Divider(),
                        _buildDocItem('Tarjeta de Propiedad', documentos['tarjeta_url'], 'conductores/$uid/documentos/tarjeta_propiedad.jpg', 'tarjeta_url'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text('Los documentos serán validados por el equipo administrativo.', 
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocItem(String label, String? url, String path, String field) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(url != null ? Icons.check_circle : Icons.description_outlined, 
          color: url != null ? const Color(0xFF10B981) : const Color(0xFFD1D5DB)),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: TextButton(
        onPressed: () => _pickDoc(path, field),
        child: Text(url != null ? 'ACTUALIZAR' : 'SUBIR', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _pickDoc(String path, String field) async {
    // Aquí podrías mostrar el ImagePickerWidget en un modal o similar
    // Para simplificar, usamos un diálogo rápido
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: ImagePickerWidget(
          label: 'Subir Documento',
          storagePath: path,
          onImagenSubida: (url) {
            _updateNestedField('documentos', field, url);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  Future<void> _updateField(String field, String value) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('usuarios').doc(uid).update({field: value});
  }

  Future<void> _updateNestedField(String mapField, String field, String value) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('usuarios').doc(uid).update({
      '$mapField.$field': value,
    });
  }
}
