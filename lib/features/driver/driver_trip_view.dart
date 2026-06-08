import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/trip_service.dart';

class DriverTripView extends StatefulWidget {
  final String viajeId;
  final Map<String, dynamic> conductorData;

  const DriverTripView({
    super.key,
    required this.viajeId,
    required this.conductorData,
  });

  @override
  State<DriverTripView> createState() => _DriverTripViewState();
}

class _DriverTripViewState extends State<DriverTripView> {
  final _tripService = TripService();
  bool _cerrando = false;

  Future<void> _cerrarViaje() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar viaje',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que deseas cerrar este viaje? Los asientos quedarán liberados.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar viaje',
                style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _cerrando = true);
      try {
        await _tripService.cerrarViaje(widget.viajeId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          setState(() => _cerrando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cerrar viaje: $e'),
              backgroundColor: const Color(0xFFFF3B30),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('Viaje activo',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        leading: const SizedBox(),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _tripService.getViajeStream(widget.viajeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text('Viaje no encontrado',
                    style: TextStyle(color: Colors.white)));
          }

          final viaje = snapshot.data!.data() as Map<String, dynamic>;
          final asientos =
              (viaje['asientos'] as Map?)?.cast<String, dynamic>() ?? {};
          final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 4;
          final asientosOcupados =
              (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
          final rutaLabel = viaje['rutaLabel'] ?? '';

          final pasajeros = asientos.values
              .where((a) =>
          (a as Map?)?.cast<String, dynamic>()?['estado'] ==
              'ocupado' &&
              (a as Map?)?.cast<String, dynamic>()?['pasajero'] != null)
              .map((a) =>
              ((a as Map).cast<String, dynamic>()['pasajero']
              as Map)
                  .cast<String, dynamic>())
              .toList();

          return SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner viaje activo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_car_rounded,
                              color: Colors.white, size: 28),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('EN CURSO',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(rutaLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '$asientosOcupados de $capacidad asientos ocupados',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Gráfico de asientos (RF51)
                const Text('Distribución de asientos',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _buildAsientosGrid(asientos, capacidad),
                const SizedBox(height: 8),

                // Leyenda
                Row(
                  children: [
                    _leyenda(const Color(0xFF10B981), 'Libre'),
                    const SizedBox(width: 16),
                    _leyenda(const Color(0xFF1E6BFF), 'Ocupado'),
                    const SizedBox(width: 16),
                    _leyenda(const Color(0xFFF59E0B), 'Bloqueado'),
                  ],
                ),
                const SizedBox(height: 24),

                // Lista de pasajeros (RF15)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Lista de pasajeros',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    Text('${pasajeros.length} pasajero(s)',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),

                pasajeros.isEmpty
                    ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border:
                    Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.people_outline,
                          color: Color(0xFF6B7280), size: 36),
                      SizedBox(height: 8),
                      Text('Sin pasajeros aún',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14)),
                    ],
                  ),
                )
                    : Column(
                  children:
                  pasajeros.map((p) => _pasajeroCard(p)).toList(),
                ),

                const SizedBox(height: 32),

                // Botón cerrar viaje
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _cerrando ? null : _cerrarViaje,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: _cerrando
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.stop_circle_outlined),
                    label: Text(
                        _cerrando ? 'Cerrando...' : 'Cerrar viaje',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAsientosGrid(
      Map<String, dynamic> asientos, int capacidad) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: capacidad,
        itemBuilder: (context, index) {
          final key = 'asiento_${index + 1}';
          final asiento =
              (asientos[key] as Map?)?.cast<String, dynamic>() ?? {};
          final estado = asiento['estado'] ?? 'libre';

          Color color;
          IconData icon;
          if (estado == 'ocupado') {
            color = const Color(0xFF1E6BFF);
            icon = Icons.person;
          } else if (estado == 'bloqueado') {
            color = const Color(0xFFF59E0B);
            icon = Icons.lock_outline;
          } else {
            color = const Color(0xFF10B981);
            icon = Icons.person_outline;
          }

          return Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 2),
                Text('${index + 1}',
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _pasajeroCard(Map<String, dynamic> pasajero) {
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
              color: const Color(0xFF1E6BFF).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person,
                color: Color(0xFF1E6BFF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pasajero['nombre'] ?? '-',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Asiento ${pasajero['asiento']} • Paradero: ${pasajero['paradero'] ?? '-'}',
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Confirmado',
                style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 12)),
      ],
    );
  }
}













