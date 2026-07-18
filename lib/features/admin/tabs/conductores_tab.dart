import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/auth_service.dart';
import '../conductor_ratings_view.dart';
import '../../../app_theme.dart';

class ConductoresTab extends StatefulWidget {
  final AuthService authService;
  final FirebaseFirestore db;
  final Function(String, String) onAprobar;
  final Function(String, String) onRechazar;

  const ConductoresTab({
    super.key,
    required this.authService,
    required this.db,
    required this.onAprobar,
    required this.onRechazar,
  });

  @override
  State<ConductoresTab> createState() => _ConductoresTabState();
}

class _ConductoresTabState extends State<ConductoresTab>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tc,
              indicatorColor: CabifyColors.primary,
              labelColor: CabifyColors.primary,
              unselectedLabelColor: CabifyColors.textSecondary,
              tabs: const [
                Tab(text: 'PENDIENTES'),
                Tab(text: 'OFICIALES'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tc,
              children: [_buildPendientes(), _buildAprobados()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDriverForm(),
        backgroundColor: CabifyColors.primary,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildPendientes() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.authService.getConductoresPendientes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('No hay solicitudes pendientes', style: TextStyle(color: Color(0xFF6B7280))),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _conductorCard(data, docs[i].id, pendiente: true);
          },
        );
      },
    );
  }

  Widget _buildAprobados() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db
          .collection('usuarios')
          .where('rol', isEqualTo: 'conductor')
          .where('estado', whereIn: ['activo', 'inactivo', 'pendiente_aprobacion'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No hay conductores oficiales', style: TextStyle(color: Color(0xFF6B7280))));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _conductorCard(data, docs[i].id, pendiente: false);
          },
        );
      },
    );
  }

  Widget _conductorCard(Map<String, dynamic> data, String uid, {required bool pendiente}) {
    final vehiculo = (data['vehiculo'] as Map?)?.cast<String, dynamic>() ?? {};
    final documentos = (data['documentos'] as Map?)?.cast<String, dynamic>() ?? {};
    final nombre = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}';
    final estado = data['estado'] ?? 'pendiente';

    Color statusColor = const Color(0xFF7C3AED);
    if (estado == 'activo') statusColor = const Color(0xFF10B981);
    if (estado == 'inactivo') statusColor = const Color(0xFFEF4444);
    if (estado == 'pendiente' || estado == 'pendiente_aprobacion') statusColor = const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CabifyColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ExpansionTile(
        iconColor: CabifyColors.textSecondary,
        collapsedIconColor: CabifyColors.textSecondary,
        leading: CircleAvatar(
          backgroundColor: CabifyColors.primary.withValues(alpha: 0.1),
          backgroundImage: data['fotoUrl'] != null ? NetworkImage(data['fotoUrl']) : null,
          child: data['fotoUrl'] == null ? const Icon(Icons.person, color: CabifyColors.primary) : null,
        ),
        title: Row(
          children: [
            Expanded(child: Text(nombre, style: const TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                estado.toString().toUpperCase(),
                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Text(pendiente ? 'Solicitud pendiente' : 'Código: ${data['codigoConductor'] ?? "-"}', 
          style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DATOS DEL VEHÍCULO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CabifyColors.textSecondary, letterSpacing: 1)),
                const SizedBox(height: 12),
                _infoRow(Icons.badge_outlined, 'DNI', data['dni'] ?? '-'),
                _infoRow(Icons.phone_android_outlined, 'Celular', data['celular'] ?? '-'),
                _infoRow(Icons.directions_car_outlined, 'Placa', vehiculo['placa'] ?? '-'),
                _infoRow(Icons.commute_outlined, 'Marca/Modelo', '${vehiculo['marca'] ?? ''} ${vehiculo['modelo'] ?? ''}'),
                
                const Divider(height: 32, color: CabifyColors.border),
                const Text('DOCUMENTOS (PDF)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CabifyColors.textSecondary, letterSpacing: 1)),
                const SizedBox(height: 12),
                _docLink('DNI', documentos['dni']?['url']),
                _docLink('Licencia', documentos['licencia']?['url']),
                _docLink('Tarjeta Propiedad', documentos['tarjeta_propiedad']?['url']),
                
                const SizedBox(height: 24),
                
                // Botones de acción
                Row(
                  children: [
                    if (!pendiente) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _toggleEstado(uid, estado),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: estado == 'activo' ? CabifyColors.error : CabifyColors.success,
                            side: BorderSide(color: estado == 'activo' ? CabifyColors.error : CabifyColors.success),
                          ),
                          child: Text(estado == 'activo' ? 'DESACTIVAR' : 'ACTIVAR', style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showDriverForm(uid: uid, initialData: data),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6), foregroundColor: CabifyColors.textPrimary, elevation: 0),
                          child: const Text('EDITAR', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                    if (pendiente) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => widget.onRechazar(uid, nombre),
                          style: OutlinedButton.styleFrom(foregroundColor: CabifyColors.error, side: const BorderSide(color: CabifyColors.error)),
                          child: const Text('RECHAZAR', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => widget.onAprobar(uid, nombre),
                          style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.success),
                          child: const Text('APROBAR', style: TextStyle(fontSize: 11, color: Colors.white)),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!pendiente) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ConductorRatingsView(conductorUid: uid, conductorNombre: nombre)));
                      },
                      icon: const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      label: const Text('VER CALIFICACIONES', style: TextStyle(fontSize: 11, color: CabifyColors.textSecondary)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: CabifyColors.border)),
                    ),
                  ),
                ],
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: CabifyColors.textSecondary, size: 14),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 13)),
          Expanded(child: Text(val, style: const TextStyle(color: CabifyColors.textPrimary, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _docLink(String label, String? url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(url != null ? Icons.check_circle : Icons.error_outline, 
               color: url != null ? CabifyColors.success : CabifyColors.error, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13, color: CabifyColors.textSecondary)),
          const Spacer(),
          if (url != null)
            TextButton(
              onPressed: () => launchUrl(Uri.parse(url)),
              child: const Text('VER PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CabifyColors.primary)),
            )
          else
            const Text('FALTANTE', style: TextStyle(fontSize: 10, color: CabifyColors.error, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _toggleEstado(String uid, String currentStatus) async {
    final nextStatus = currentStatus == 'activo' ? 'inactivo' : 'activo';
    await widget.db.collection('usuarios').doc(uid).update({'estado': nextStatus});
  }

  void _showDriverForm({String? uid, Map<String, dynamic>? initialData}) {
    final data = initialData;
    final isEditing = uid != null;
    final nombreCtrl = TextEditingController(text: data?['nombre']);
    final apellidoCtrl = TextEditingController(text: data?['apellido']);
    final dniCtrl = TextEditingController(text: data?['dni']);
    final celularCtrl = TextEditingController(text: data?['celular']);
    final placaCtrl = TextEditingController(text: data?['vehiculo']?['placa']);
    final marcaCtrl = TextEditingController(text: data?['vehiculo']?['marca']);
    final modeloCtrl = TextEditingController(text: data?['vehiculo']?['modelo']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEditing ? 'Editar Conductor' : 'Nuevo Conductor', 
          style: const TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 12),
              TextField(controller: apellidoCtrl, decoration: const InputDecoration(labelText: 'Apellido')),
              const SizedBox(height: 12),
              TextField(controller: dniCtrl, decoration: const InputDecoration(labelText: 'DNI'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: celularCtrl, decoration: const InputDecoration(labelText: 'Celular'), keyboardType: TextInputType.phone),
              const Divider(height: 40, color: CabifyColors.border),
              TextField(controller: placaCtrl, decoration: const InputDecoration(labelText: 'Placa')),
              const SizedBox(height: 12),
              TextField(controller: marcaCtrl, decoration: const InputDecoration(labelText: 'Marca')),
              const SizedBox(height: 12),
              TextField(controller: modeloCtrl, decoration: const InputDecoration(labelText: 'Modelo')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR', style: TextStyle(color: CabifyColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              final dni = dniCtrl.text.trim();
              final celular = celularCtrl.text.trim();
              final sm = ScaffoldMessenger.of(context);
              
              if (dni.isEmpty || celular.isEmpty || nombreCtrl.text.isEmpty) {
                sm.showSnackBar(const SnackBar(content: Text('Complete los campos obligatorios'), backgroundColor: CabifyColors.error));
                return;
              }

              final String? oldDni = isEditing ? (initialData?['dni'] as String?) : null;
              if (!isEditing || (isEditing && dni != oldDni)) {
                if (await widget.authService.isDniRegistered(dni)) {
                  if (!mounted) return;
                  sm.showSnackBar(const SnackBar(content: Text('Este DNI ya está registrado en el sistema.'), backgroundColor: CabifyColors.error));
                  return;
                }
              }

              final String? oldCelular = isEditing ? (initialData?['celular'] as String?) : null;
              if (!isEditing || (isEditing && celular != oldCelular)) {
                if (await widget.authService.isCelularRegistered(celular)) {
                  if (!mounted) return;
                  sm.showSnackBar(const SnackBar(content: Text('Este número de celular ya está registrado.'), backgroundColor: CabifyColors.error));
                  return;
                }
              }

              final newData = {
                'nombre': nombreCtrl.text.trim(),
                'apellido': apellidoCtrl.text.trim(),
                'dni': dni,
                'celular': celular,
                'vehiculo': {
                  'placa': placaCtrl.text.trim(),
                  'marca': marcaCtrl.text.trim(),
                  'modelo': modeloCtrl.text.trim(),
                },
              };

              if (isEditing) {
                await widget.db.collection('usuarios').doc(uid).update(newData);
              } else {
                final newId = widget.db.collection('usuarios').doc().id;
                await widget.db.collection('usuarios').doc(newId).set({
                  ...newData,
                  'uid': newId,
                  'rol': 'conductor',
                  'estado': 'pendiente',
                  'creadoEn': FieldValue.serverTimestamp(),
                  'email': '$celular@sicol.pe',
                });
              }

              if (context.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.primary),
            child: Text(isEditing ? 'GUARDAR' : 'REGISTRAR', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
