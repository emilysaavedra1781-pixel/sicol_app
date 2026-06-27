import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/trip_service.dart';
import 'driver_drawer.dart';

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
      backgroundColor: const Color(0xFF0A0E1A),
      drawer: const DriverDrawer(currentRoute: 'viajes'),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('Mis viajes',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _tripService.getHistorialViajes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar viajes: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white)),
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
                        color: Color(0xFF6B7280), size: 40),
                    SizedBox(height: 10),
                    Text(
                      'Aún no tienes viajes registrados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
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
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              Text(fechaTexto,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.people_outline,
                  color: Color(0xFF6B7280), size: 14),
              const SizedBox(width: 6),
              Text('$asientos/$capacidad pasajeros',
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 12)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E6BFF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(estado,
                    style: const TextStyle(
                        color: Color(0xFF1E6BFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}