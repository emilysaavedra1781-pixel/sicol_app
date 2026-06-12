import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'seat_selection_view.dart';

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
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Detalle del colectivo'),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: db.collection('viajes').doc(viajeId).snapshots(),
        builder: (context, viajeSnap) {
          if (!viajeSnap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
          }
          if (!viajeSnap.data!.exists) {
            return const Center(
                child: Text('Viaje no disponible.',
                    style: TextStyle(color: Colors.white)));
          }

          final viaje = viajeSnap.data!.data() as Map<String, dynamic>;
          final conductorUid = viaje['conductorUid'] as String? ?? '';
          final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 4;
          final asientosOcupados =
              (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
          final libres = capacidad - asientosOcupados;
          final vehiculo =
              (viaje['vehiculo'] as Map?)?.cast<String, dynamic>() ?? {};
          final rutaLabel = viaje['rutaLabel'] ??
              (rutaSeleccionada == 'chosica_lima'
                  ? 'Chosica → Lima'
                  : 'Lima → Chosica');

          return FutureBuilder<DocumentSnapshot>(
            future: db.collection('usuarios').doc(conductorUid).get(),
            builder: (context, userSnap) {
              final userData = userSnap.hasData && userSnap.data!.exists
                  ? (userSnap.data!.data() as Map<String, dynamic>)
                  : <String, dynamic>{};

              final nombre = userData['nombre'] ?? viaje['conductorNombre'] ?? 'Conductor';
              final apellido = userData['apellido'] ?? '';
              final fotoUrl = userData['fotoUrl'] as String?;
              final licencia = userData['numeroLicencia'] as String?;

              // Vehiculo data — puede venir del doc usuario o del viaje
              final vData = (userData['vehiculo'] as Map?)
                  ?.cast<String, dynamic>() ??
                  vehiculo;
              final placa = vData['placa'] as String? ?? '-';
              final marca = vData['marca'] as String? ?? '-';
              final modelo = vData['modelo'] as String? ?? '-';
              final color = vData['color'] as String? ?? '-';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Tarjeta conductor ────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(18),
                        border:
                        Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Conductor',
                              style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              // Avatar
                              Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF1E6BFF)
                                      .withOpacity(0.15),
                                  border: Border.all(
                                      color: const Color(0xFF1E6BFF)
                                          .withOpacity(0.3),
                                      width: 2),
                                  image: fotoUrl != null
                                      ? DecorationImage(
                                      image: NetworkImage(fotoUrl),
                                      fit: BoxFit.cover)
                                      : null,
                                ),
                                child: fotoUrl == null
                                    ? const Icon(Icons.person_rounded,
                                    color: Color(0xFF1E6BFF), size: 30)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$nombre $apellido'.trim(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700),
                                    ),
                                    if (licencia != null) ...[
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        const Icon(
                                            Icons.card_membership_outlined,
                                            color: Color(0xFF6B7280),
                                            size: 13),
                                        const SizedBox(width: 4),
                                        Text('Licencia: $licencia',
                                            style: const TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 12)),
                                      ]),
                                    ],
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withOpacity(0.12),
                                        borderRadius:
                                        BorderRadius.circular(6),
                                      ),
                                      child: const Text('Activo',
                                          style: TextStyle(
                                              color: Color(0xFF10B981),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Tarjeta vehículo ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(18),
                        border:
                        Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Vehículo',
                              style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 14),
                          // Placa destacada
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0E1A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF1E6BFF)
                                      .withOpacity(0.25)),
                            ),
                            child: Column(
                              children: [
                                const Text('PLACA',
                                    style: TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 10,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(placa,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 4)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                  child: _infoItem(
                                      Icons.directions_car_outlined,
                                      'Marca',
                                      marca)),
                              Expanded(
                                  child: _infoItem(
                                      Icons.car_repair_outlined,
                                      'Modelo',
                                      modelo)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                  child: _infoItem(
                                      Icons.color_lens_outlined,
                                      'Color',
                                      color)),
                              Expanded(
                                  child: _infoItem(
                                      Icons.people_outline,
                                      'Capacidad',
                                      '$capacidad pasajeros')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Tarjeta viaje ────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(18),
                        border:
                        Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Detalles del viaje',
                              style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 14),
                          _infoItem(Icons.route_outlined, 'Ruta',
                              rutaLabel),
                          const SizedBox(height: 10),
                          _infoItem(Icons.location_on_outlined,
                              'Tu paradero', paradero),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _infoItem(
                                  Icons.event_seat_rounded,
                                  'Asientos libres',
                                  '$libres de $capacidad',
                                  valueColor: libres > 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFFF3B30),
                                ),
                              ),
                              Expanded(
                                child: _infoItem(
                                    Icons.attach_money_rounded,
                                    'Precio',
                                    'S/ 15.00',
                                    valueColor:
                                    const Color(0xFF1E6BFF)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Botón reservar ───────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: libres > 0
                            ? () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SeatSelectionView(
                              viajeId: viajeId,
                              paradero: paradero,
                              rutaSeleccionada: rutaSeleccionada,
                            ),
                          ),
                        )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E6BFF),
                          disabledBackgroundColor:
                          const Color(0xFF1F2937),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(
                            Icons.confirmation_number_rounded,
                            size: 18),
                        label: Text(
                          libres > 0
                              ? 'Elegir asiento'
                              : 'Sin asientos disponibles',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF6B7280), size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: valueColor ?? Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}