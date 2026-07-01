import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app_theme.dart';

class ViajesTab extends StatelessWidget {
  final FirebaseFirestore db;
  const ViajesTab({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('viajes').orderBy('iniciadoEn', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No hay registros de viajes', style: TextStyle(color: CabifyColors.textSecondary)));

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final enCamino = data['estado'] == 'en_camino';
            final activo = data['estado'] == 'activo';
            final finalizado = data['estado'] == 'finalizado';

            return Card(
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: finalizado ? Colors.grey[200] : CabifyColors.primary.withValues(alpha: 0.1),
                  backgroundImage: data['conductorFotoUrl'] != null ? NetworkImage(data['conductorFotoUrl']) : null,
                  child: data['conductorFotoUrl'] == null 
                      ? Icon(Icons.directions_car, color: finalizado ? Colors.grey : CabifyColors.primary)
                      : null,
                ),
                title: Text(data['conductorNombre'] ?? 'Conductor', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${data['rutaLabel'] ?? 'Sin asignar'} · ${data['asientosOcupados']} PAX'),
                trailing: _buildBadge(data['estado']?.toString().toUpperCase() ?? 'DESCONOCIDO'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoItem('Vehículo', '${data['vehiculo']?['marca']} ${data['vehiculo']?['modelo']}'),
                        _infoItem('Placa', data['vehiculo']?['placa'] ?? '-'),
                        _infoItem('Ingresos', 'S/ ${data['ingresoTotal'] ?? 0}'),
                        const SizedBox(height: 16),
                        const Text('PASAJEROS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: CabifyColors.textSecondary)),
                        const SizedBox(height: 8),
                        ..._buildPassengersList(data['asientos'] ?? {}),
                        const SizedBox(height: 16),
                        if (!finalizado)
                          ElevatedButton(
                            onPressed: () => _forzarFinalizacion(context, id),
                            style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.error),
                            child: const Text('FINALIZAR VIAJE (ADMIN)'),
                          ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildPassengersList(Map<String, dynamic> asientos) {
    List<Widget> list = [];
    asientos.forEach((key, val) {
      if (val['pasajero'] != null) {
        list.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Text('• Asiento ${val['numero']}: ${val['pasajero']['nombre']} (${val['pasajero']['paradero']})',
            style: const TextStyle(fontSize: 12)),
        ));
      }
    });
    if (list.isEmpty) list.add(const Text('No hay pasajeros registrados', style: TextStyle(fontSize: 12, color: Colors.grey)));
    return list;
  }

  Widget _buildBadge(String status) {
    Color color = Colors.grey;
    if (status == 'ACTIVO') color = CabifyColors.success;
    if (status == 'EN_CAMINO') color = CabifyColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _forzarFinalizacion(BuildContext context, String viajeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Cierre', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de finalizar este viaje de forma remota?', style: TextStyle(color: CabifyColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: CabifyColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.error, foregroundColor: Colors.white),
            child: const Text('SÍ, FINALIZAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await db.collection('viajes').doc(viajeId).update({'estado': 'finalizado', 'cerradoPorAdmin': true});
    }
  }
}
