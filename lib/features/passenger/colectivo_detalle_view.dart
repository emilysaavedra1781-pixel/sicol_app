import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'seat_selection_view.dart';
import '../../app_theme.dart';

class ColectivoDetalleView extends StatelessWidget {
  final String viajeId;
  final String paradero;
  final String? rutaSeleccionada;

  const ColectivoDetalleView({
    super.key,
    required this.viajeId,
    required this.paradero,
    this.rutaSeleccionada,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CabifyColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Detalles del Viaje', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: db.collection('viajes').doc(viajeId).snapshots(),
        builder: (context, viajeSnap) {
          if (!viajeSnap.hasData) return const Center(child: CircularProgressIndicator());
          if (!viajeSnap.data!.exists) return const Center(child: Text('Viaje no disponible.'));

          final viaje = viajeSnap.data!.data() as Map<String, dynamic>;
          final conductorUid = viaje['conductorUid'] as String? ?? '';
          final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 4;
          final asientosOcupados = (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
          final libres = capacidad - asientosOcupados;
          
          return FutureBuilder<DocumentSnapshot>(
            future: db.collection('usuarios').doc(conductorUid).get(),
            builder: (context, userSnap) {
              final userData = userSnap.hasData && userSnap.data!.exists
                  ? (userSnap.data!.data() as Map<String, dynamic>)
                  : <String, dynamic>{};

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                              backgroundImage: userData['fotoUrl'] != null ? NetworkImage(userData['fotoUrl']) : null,
                              child: userData['fotoUrl'] == null ? Icon(Icons.person, size: 40, color: Theme.of(context).primaryColor) : null,
                            ),
                            const SizedBox(height: 16),
                            Text(viaje['conductorNombre'] ?? 'Conductor', 
                                style: Theme.of(context).textTheme.titleLarge),
                            const Text('Conductor verificado', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (viaje['vehiculo']?['fotoVehiculoUrl'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          viaje['vehiculo']['fotoVehiculoUrl'],
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildInfoRow(context, Icons.directions_car, 'Vehículo', '${viaje['vehiculo']?['marca']} · ${viaje['vehiculo']?['modelo']}'),
                            const Divider(height: 32),
                            _buildInfoRow(context, Icons.badge, 'Placa', viaje['vehiculo']?['placa'] ?? '-'),
                            const Divider(height: 32),
                            _buildInfoRow(context, Icons.event_seat, 'Disponibilidad', '$libres asientos libres'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: libres > 0 ? () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SeatSelectionView(
                          viajeId: viajeId,
                          paradero: paradero,
                          rutaSeleccionada: rutaSeleccionada,
                        )));
                      } : null,
                      child: const Text('CONTINUAR A ASIENTOS'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6B7280), size: 20),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ],
    );
  }
}
