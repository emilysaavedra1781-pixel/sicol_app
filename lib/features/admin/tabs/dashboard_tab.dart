import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../app_theme.dart';

class DashboardTab extends StatelessWidget {
  final FirebaseFirestore db;
  const DashboardTab({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('viajes').snapshots(),
      builder: (context, viajesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('reservas').snapshots(),
          builder: (context, reservasSnap) {
            if (viajesSnap.hasError || reservasSnap.hasError) {
              // CP10: Error de conexión
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al conectar con Firestore. Verifique su conexión.'),
                    backgroundColor: Colors.red,
                  ),
                );
              });
            }

            final allViajes = viajesSnap.data?.docs ?? [];
            final allReservas = reservasSnap.data?.docs ?? [];

            // CP02: Viajes activos (estado activo o en_camino del día actual)
            final viajesActivos = allViajes.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final date = (d['iniciadoEn'] as Timestamp?)?.toDate();
              return (d['estado'] == 'activo' || d['estado'] == 'en_camino') &&
                  date != null &&
                  date.isAfter(startOfDay) &&
                  date.isBefore(endOfDay);
            }).toList();

            // CP03: Ingresos del día (Pagos completados del día actual)
            double ingresosTotal = 0;
            final reservasHoy = allReservas.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final date = (d['creadoEn'] as Timestamp?)?.toDate();
              return date != null && date.isAfter(startOfDay) && date.isBefore(endOfDay);
            }).toList();
            for (var r in reservasHoy) {
              ingresosTotal += (r['monto'] as num?)?.toDouble() ?? 0;
            }

            // CP04: Pasajeros en curso (reservas en estado abordado)
            final pasajerosEnCurso = allReservas.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return d['estado'] == 'abordado';
            }).toList();

            // CP05: Colectivos disponibles (estado activo)
            final disponibles = allViajes.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return d['estado'] == 'activo';
            }).toList();

            // CP06: Colectivos finalizados (finalizado hoy)
            final finalizadosHoy = allViajes.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final date = (d['cerradoEn'] as Timestamp?)?.toDate();
              return d['estado'] == 'finalizado' &&
                  date != null &&
                  date.isAfter(startOfDay) &&
                  date.isBefore(endOfDay);
            }).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RESUMEN OPERATIVO - HOY',
                    style: TextStyle(
                        color: CabifyColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 20),
                  // CP01: Todos los indicadores
                  _metricCard(
                    context,
                    label: 'VIAJES ACTIVOS',
                    value: viajesActivos.length.toString(),
                    icon: Icons.local_taxi_rounded,
                    color: CabifyColors.primary,
                    onTap: () => _navToDetail(context, 'Viajes Activos', viajesActivos),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _metricCard(
                          context,
                          label: 'INGRESOS',
                          value: 'S/ ${ingresosTotal.toStringAsFixed(2)}',
                          icon: Icons.attach_money_rounded,
                          color: const Color(0xFF10B981),
                          onTap: () => _navToDetail(context, 'Ingresos de Hoy', reservasHoy),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _metricCard(
                          context,
                          label: 'PASAJEROS',
                          value: pasajerosEnCurso.length.toString(),
                          icon: Icons.people_alt_rounded,
                          color: Colors.blueAccent,
                          onTap: () => _navToDetail(context, 'Pasajeros en Curso', pasajerosEnCurso),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _metricCard(
                          context,
                          label: 'DISPONIBLES',
                          value: disponibles.length.toString(),
                          icon: Icons.event_seat_rounded,
                          color: Colors.orangeAccent,
                          onTap: () => _navToDetail(context, 'Colectivos Disponibles', disponibles),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _metricCard(
                          context,
                          label: 'FINALIZADOS',
                          value: finalizadosHoy.length.toString(),
                          icon: Icons.flag_rounded,
                          color: Colors.grey,
                          onTap: () => _navToDetail(context, 'Finalizados Hoy', finalizadosHoy),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _metricCard(BuildContext context,
      {required String label,
      required String value,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Icon(Icons.chevron_right_rounded, color: CabifyColors.textSecondary, size: 18),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                  color: CabifyColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  color: CabifyColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  void _navToDetail(BuildContext context, String title, List<DocumentSnapshot> items) {
    // CP07: Navegación al detalle
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminMetricDetailView(title: title, items: items),
      ),
    );
  }
}

class AdminMetricDetailView extends StatelessWidget {
  final String title;
  final List<DocumentSnapshot> items;

  const AdminMetricDetailView({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CabifyColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16, color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: items.isEmpty
          ? Center(
              child: Text('No hay datos registrados.',
                  style: TextStyle(color: CabifyColors.textSecondary)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final data = items[i].data() as Map<String, dynamic>;
                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      data['nombreViajero'] ?? data['conductorNombre'] ?? 'Elemento ID: ${items[i].id}',
                      style: const TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Estado: ${data['estado'] ?? 'N/A'} · Ruta: ${data['rutaLabel'] ?? data['paradero'] ?? '-'}',
                      style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 12),
                    ),
                    trailing: data['monto'] != null
                        ? Text('S/ ${data['monto']}',
                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold))
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
