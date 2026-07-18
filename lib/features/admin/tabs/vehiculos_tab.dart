import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app_theme.dart';

class VehiculosTab extends StatefulWidget {
  final FirebaseFirestore db;
  const VehiculosTab({super.key, required this.db});

  @override
  State<VehiculosTab> createState() => _VehiculosTabState();
}

class _VehiculosTabState extends State<VehiculosTab> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: CabifyColors.primary,
          unselectedLabelColor: CabifyColors.textSecondary,
          indicatorColor: CabifyColors.primary,
          tabs: const [
            Tab(text: 'PENDIENTES'),
            Tab(text: 'APROBADOS'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildVehiculosList('pendiente'),
              _buildVehiculosList('aprobado'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehiculosList(String estadoFiltro) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db
          .collection('usuarios')
          .where('rol', isEqualTo: 'conductor')
          .where('vehiculo.estado', isEqualTo: estadoFiltro)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car_filled_outlined, color: Colors.grey[300], size: 64),
                const SizedBox(height: 16),
                Text('No hay vehículos $estadoFiltro.', style: const TextStyle(color: CabifyColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final vehiculo = data['vehiculo'] as Map<String, dynamic>? ?? {};
            final uid = docs[i].id;
            final conductorNombre = '${data['nombre']} ${data['apellido']}';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(vehiculo['placa'] ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CabifyColors.primary)),
                        _statusBadge(vehiculo['estado'] ?? 'pendiente'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoRow(Icons.person, 'Conductor', conductorNombre),
                    _infoRow(Icons.directions_car, 'Vehículo', '${vehiculo['marca']} ${vehiculo['modelo']}'),
                    _infoRow(Icons.palette, 'Color', vehiculo['color'] ?? '-'),
                    _infoRow(Icons.event_seat, 'Capacidad', '${vehiculo['capacidad']} asientos'),
                    if (vehiculo['motivoRechazo'] != null && vehiculo['estado'] == 'rechazado')
                      _infoRow(Icons.error_outline, 'Motivo rechazo', vehiculo['motivoRechazo'], color: Colors.red),
                    
                    if (estadoFiltro == 'pendiente') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _rechazarDialog(uid),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                              child: const Text('RECHAZAR'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _actualizarEstado(uid, 'aprobado'),
                              style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.success, foregroundColor: Colors.white),
                              child: const Text('APROBAR'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? CabifyColors.textSecondary),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: color ?? CabifyColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: TextStyle(color: color ?? CabifyColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.amber;
    if (status == 'aprobado') color = CabifyColors.success;
    if (status == 'rechazado') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _actualizarEstado(String uid, String nuevoEstado, {String? motivo}) async {
    try {
      final Map<String, dynamic> update = {
        'vehiculo.estado': nuevoEstado,
        'vehiculo.fechaDecision': FieldValue.serverTimestamp(),
      };
      if (motivo != null) update['vehiculo.motivoRechazo'] = motivo;

      await widget.db.collection('usuarios').doc(uid).update(update);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vehículo $nuevoEstado correctamente'), backgroundColor: CabifyColors.success)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _rechazarDialog(String uid) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar Vehículo'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Escribe el motivo del rechazo...'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _actualizarEstado(uid, 'rechazado', motivo: ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('RECHAZAR'),
          ),
        ],
      ),
    );
  }
}
