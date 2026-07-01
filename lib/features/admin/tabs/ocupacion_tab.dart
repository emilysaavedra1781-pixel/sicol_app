import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app_theme.dart';

class OcupacionTab extends StatelessWidget {
  final FirebaseFirestore db;
  const OcupacionTab({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // CP02: Solo colectivos activos o en camino
      stream: db.collection('viajes')
          .where('estado', whereIn: ['activo', 'en_camino'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // CP07: Error en la consulta
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: CabifyColors.error, size: 48),
                const SizedBox(height: 16),
                const Text('Error al cargar la ocupación', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: CabifyColors.primary));
        }

        final viajes = snapshot.data?.docs ?? [];

        // CP06: Sin colectivos activos
        if (viajes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.airline_seat_recline_extra_rounded, color: Colors.grey[300], size: 64),
                const SizedBox(height: 16),
                const Text(
                  'No hay colectivos activos disponibles.',
                  style: TextStyle(color: CabifyColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: viajes.length,
          itemBuilder: (context, i) {
            final viaje = viajes[i].data() as Map<String, dynamic>;
            final asientos = viaje['asientos'] as Map<String, dynamic>? ?? {};
            final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 4;
            final conductor = viaje['conductorNombre'] ?? 'Conductor';
            final ruta = viaje['rutaLabel'] ?? 'Sin ruta';
            final estadoViaje = viaje['estado'] ?? 'activo';

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CabifyColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabecera del Colectivo
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: CabifyColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.drive_eta_rounded, color: CabifyColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(conductor, style: const TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
                              Text(ruta, style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (estadoViaje == 'en_camino' ? CabifyColors.primary : CabifyColors.success).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            estadoViaje == 'en_camino' ? 'EN RUTA' : 'EN ESPERA',
                            style: TextStyle(
                              color: estadoViaje == 'en_camino' ? CabifyColors.primary : CabifyColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: CabifyColors.border),
                  
                  // CP01, CP03, CP04, CP05: Mapa de Asientos
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('OCUPACIÓN DE ASIENTOS', 
                          style: TextStyle(color: CabifyColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 16),
                        _buildSeatsGrid(asientos, capacidad),
                        const SizedBox(height: 16),
                        _buildLegend(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSeatsGrid(Map<String, dynamic> asientos, int capacidad) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: capacidad,
      itemBuilder: (context, index) {
        final key = 'asiento_${index + 1}';
        final asiento = (asientos[key] as Map?)?.cast<String, dynamic>() ?? {};
        final estado = asiento['estado'] ?? 'libre';
        
        Color color;
        IconData icon;
        bool isOccupied = estado == 'ocupado' || estado == 'abordado';

        if (estado == 'ocupado') {
          color = const Color(0xFFF59E0B); // Ámbar para reservado
          icon = Icons.person;
        } else if (estado == 'abordado') {
          color = CabifyColors.success;
          icon = Icons.check_circle;
        } else if (estado == 'bloqueado') {
          color = CabifyColors.error;
          icon = Icons.lock_outline;
        } else {
          color = const Color(0xFFE5E7EB);
          icon = Icons.event_seat_outlined;
        }

        return Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text('${index + 1}', 
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendItem(const Color(0xFFD1D5DB), 'Libre'),
        const SizedBox(width: 12),
        _legendItem(const Color(0xFFF59E0B), 'Reservado'),
        const SizedBox(width: 12),
        _legendItem(CabifyColors.success, 'Abordado'),
        const SizedBox(width: 12),
        _legendItem(CabifyColors.error, 'Bloqueado'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 9)),
      ],
    );
  }
}
