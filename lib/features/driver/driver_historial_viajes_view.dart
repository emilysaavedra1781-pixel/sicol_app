import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/trip_service.dart';
import 'driver_drawer.dart';
import 'driver_home_view.dart';
import 'driver_viaje_detalle_view.dart';
import '../../app_theme.dart';

/// Historial de viajes del conductor (sin información de ingresos).
class DriverHistorialViajesView extends StatefulWidget {
  const DriverHistorialViajesView({super.key});

  @override
  State<DriverHistorialViajesView> createState() =>
      _DriverHistorialViajesViewState();
}

class _DriverHistorialViajesViewState
    extends State<DriverHistorialViajesView> {
  final _tripService = TripService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const DriverDrawer(currentRoute: 'viajes'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CabifyColors.primary),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DriverHomeView()),
              );
            }
          },
        ),
        title: const Text('Mis viajes',
            style: TextStyle(
                color: CabifyColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _tripService.getHistorialViajes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: CabifyColors.primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: CabifyColors.error, size: 40),
                    const SizedBox(height: 16),
                    Text('Error al cargar viajes: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            );
          }

          final viajes = snapshot.data ?? [];

          if (viajes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.route_outlined,
                        color: CabifyColors.textSecondary, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'Aún no tienes viajes registrados. Tus viajes finalizados aparecerán aquí.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: CabifyColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: viajes.length,
            itemBuilder: (context, i) => _viajeCard(viajes[i]),
          );
        },
      ),
    );
  }

  Widget _viajeCard(Map<String, dynamic> viaje) {
    final rutaLabel = viaje['rutaLabel'] ?? 'Sin ruta';
    final asientos = (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
    final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 0;
    final cerradoEn = viaje['cerradoEn'];
    final fechaTexto =
    cerradoEn is Timestamp ? _fmt(cerradoEn.toDate()) : '-';
    final estado = viaje['estado'] ?? 'finalizado';
    
    // CP05: Cálculo del monto (S/10 por pasajero)
    final montoConductor = asientos * 10.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DriverViajeDetalleView(viaje: viaje)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CabifyColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(rutaLabel,
                      style: const TextStyle(
                          color: CabifyColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                Text(fechaTexto,
                    style: const TextStyle(
                        color: CabifyColors.textSecondary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.people_outline,
                    color: CabifyColors.textSecondary, size: 14),
                const SizedBox(width: 6),
                Text('$asientos/$capacidad pasajeros',
                    style: const TextStyle(
                        color: CabifyColors.textSecondary, fontSize: 12)),
                const Spacer(),
                Text('S/ ${montoConductor.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: CabifyColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CabifyColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(estado.toUpperCase(),
                      style: const TextStyle(
                          color: CabifyColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}