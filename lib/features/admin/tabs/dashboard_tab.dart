import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardTab extends StatelessWidget {
  final FirebaseFirestore db;
  const DashboardTab({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen operativo de hoy',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: db.collection('viajes').where('estado', isEqualTo: 'activo').snapshots(),
            builder: (context, snapActivos) {
              return StreamBuilder<QuerySnapshot>(
                stream: db.collection('viajes').where('estado', isEqualTo: 'finalizado').snapshots(),
                builder: (context, snapFinalizados) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: db
                        .collection('reservas')
                        .where('estado', isEqualTo: 'confirmada')
                        .where('fechaCreacion', isGreaterThanOrEqualTo: inicioHoy)
                        .snapshots(),
                    builder: (context, snapReservas) {
                      final activos = snapActivos.data?.docs.length ?? 0;
                      final finalizados = snapFinalizados.data?.docs.length ?? 0;
                      final reservas = snapReservas.data?.docs ?? [];

                      double ingresos = 0;
                      for (final r in reservas) {
                        final data = r.data() as Map<String, dynamic>;
                        ingresos += (data['monto'] as num?)?.toDouble() ?? 0;
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _indicador(
                                  icon: Icons.directions_car_rounded,
                                  label: 'Colectivos en línea',
                                  valor: '$activos',
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _indicador(
                                  icon: Icons.check_circle_rounded,
                                  label: 'Viajes terminados',
                                  valor: '$finalizados',
                                  color: const Color(0xFF1E6BFF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _indicador(
                                  icon: Icons.people_rounded,
                                  label: 'Pasajeros del día',
                                  valor: '${reservas.length}',
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _indicador(
                                  icon: Icons.attach_money_rounded,
                                  label: 'Ingresos diarios',
                                  valor: 'S/ ${ingresos.toStringAsFixed(2)}',
                                  color: const Color(0xFF8B5CF6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),
          const Text('Unidades en servicio activo',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: db.collection('viajes').where('estado', isEqualTo: 'activo').snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.directions_car_outlined, color: Color(0xFF374151), size: 40),
                      SizedBox(height: 8),
                      Text('No hay colectivos activos en Carretera Central',
                          style: TextStyle(color: Color(0xFF6B7280))),
                    ],
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final ocupados = (d['asientosOcupados'] as num?)?.toInt() ?? 0;
                  final capacidad = (d['capacidad'] as num?)?.toInt() ?? 4;
                  final esEspera = d['ruta'] == 'esperando';
                  final rutaTxt = esEspera
                      ? 'Disponible (Esperando Asignación)'
                      : (d['rutaLabel'] ?? '-');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (esEspera
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981))
                                .withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.directions_car_rounded,
                            color: esEspera
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rutaTxt,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                '${d['conductorNombre'] ?? 'Conductor'} • $ocupados/$capacidad asientos',
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (esEspera
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981))
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            esEspera ? 'Espera' : 'En Ruta',
                            style: TextStyle(
                              color: esEspera
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _indicador({
    required IconData icon,
    required String label,
    required String valor,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(valor,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ],
      ),
    );
  }
}