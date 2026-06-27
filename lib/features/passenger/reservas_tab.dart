import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/booking_service.dart';
import 'mapa_seguimiento_inline.dart';
import 'mapa_seguimiento_widget.dart';
import 'calificacion_view.dart';
import '../shared/reportar_incidencia_view.dart';

class ReservasTab extends StatelessWidget {
  final String uid;
  final BookingService bookingService;

  const ReservasTab({
    super.key,
    required this.uid,
    required this.bookingService,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('reservas')
            .where('pasajeroUid', isEqualTo: uid)
            .where('estado', whereIn: ['confirmada', 'abordado', 'finalizada']) // ← CP06
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
          }
          final reservas = snapshot.data!.docs;

          // ── Agrupar reservas por viajeId ─────────────────────────────────
          final Map<String, List<DocumentSnapshot>> porViaje = {};
          for (final doc in reservas) {
            final data = doc.data() as Map<String, dynamic>;
            final viajeId = data['viajeId'] ?? '';
            porViaje.putIfAbsent(viajeId, () => []).add(doc);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mis reservas',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E6BFF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${reservas.length} activa(s)',
                            style: const TextStyle(
                                color: Color(0xFF1E6BFF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              if (reservas.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.confirmation_number_outlined,
                            color: Color(0xFF374151), size: 56),
                        const SizedBox(height: 12),
                        const Text('No tienes reservas activas',
                            style: TextStyle(
                                color: Color(0xFF6B7280), fontSize: 14)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E6BFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.search_rounded, size: 16),
                          label: const Text('Buscar colectivo'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                      final viajeId = porViaje.keys.elementAt(i);
                      final reservasDelViaje = porViaje[viajeId]!;
                      return _buildViajeCard(
                          context, viajeId, reservasDelViaje);
                    },
                    childCount: porViaje.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  // ── Tarjeta agrupada por viaje ───────────────────────────────────────────
  Widget _buildViajeCard(BuildContext context, String viajeId,
      List<DocumentSnapshot> reservas) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('viajes').doc(viajeId).snapshots(),
      builder: (context, viajeSnap) {
        if (!viajeSnap.hasData || !viajeSnap.data!.exists) {
          return const SizedBox();
        }

        final vData = viajeSnap.data!.data() as Map<String, dynamic>;
        final estadoViaje = vData['estado'] ?? 'activo';
        final enCamino = estadoViaje == 'en_camino';
        final rutaLabel = vData['rutaLabel'] ?? '-';
        final conductorNombre = vData['conductorNombre'] ?? 'Conductor';
        final vehiculo =
            (vData['vehiculo'] as Map?)?.cast<String, dynamic>() ?? {};
        final placa = vehiculo['placa'] ?? '-';
        final marca = vehiculo['marca'] ?? '-';
        final color = vehiculo['color'] ?? '-';

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enCamino
                  ? const Color(0xFF1E6BFF).withValues(alpha: 0.4)
                  : const Color(0xFF1F2937),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header del viaje ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.directions_bus_rounded,
                              color: Color(0xFF1E6BFF), size: 16),
                          const SizedBox(width: 8),
                          Text(rutaLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ]),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: enCamino
                                ? const Color(0xFF1E6BFF)
                                .withValues(alpha: 0.15)
                                : const Color(0xFF10B981)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            enCamino ? 'EN CAMINO' : 'ESPERANDO',
                            style: TextStyle(
                                color: enCamino
                                    ? const Color(0xFF1E6BFF)
                                    : const Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Info conductor y vehículo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E1A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: Column(
                        children: [
                          Row(children: [
                            const Icon(Icons.person_outline,
                                color: Color(0xFF6B7280), size: 14),
                            const SizedBox(width: 8),
                            const Text('Conductor: ',
                                style: TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 12)),
                            Expanded(
                              child: Text(conductorNombre,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.directions_car_outlined,
                                color: Color(0xFF6B7280), size: 14),
                            const SizedBox(width: 8),
                            Text('$marca · $color · ',
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 12)),
                            Text(placa,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1)),
                          ]),
                        ],
                      ),
                    ),

                    // ── Mapa — solo una vez por viaje ────────────────────
                    if (enCamino) ...[
                      const SizedBox(height: 12),
                      MapaSeguimientoInline(viajeId: viajeId),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _abrirMapaModal(context, viajeId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(
                                color: Color(0xFF10B981), width: 1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.fullscreen_rounded,
                              size: 14),
                          label: const Text('Ver mapa completo',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(
                  color: Color(0xFF1F2937), thickness: 1, height: 1),

              // ── Reservas del viaje ───────────────────────────────────────
              ...reservas.map((doc) =>
                  _buildReservaItem(context, doc, viajeId, enCamino)),
            ],
          ),
        );
      },
    );
  }

  // ── Item individual de reserva ───────────────────────────────────────────
  Widget _buildReservaItem(BuildContext context, DocumentSnapshot doc,
      String viajeId, bool enCamino) {
    final res = doc.data() as Map<String, dynamic>;
    final asiento = res['numeroAsiento'] ?? '-';
    final codigo = res['codigoVerificacion'] ?? '-----';
    final paradero = res['paradero'] ?? '-';
    final nombreViajero = res['nombreViajero'] ?? '-';
    final esAcompanante = res['esAcompanante'] == true;
    final estadoReserva = res['estado'] ?? 'confirmada';
    final yaAbordado = estadoReserva == 'abordado';
    final finalizada = estadoReserva == 'finalizada'; // ← nuevo

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre del pasajero
          Row(children: [
            Icon(
                esAcompanante
                    ? Icons.person_add_rounded
                    : Icons.person_rounded,
                color: esAcompanante
                    ? const Color(0xFF1E6BFF)
                    : const Color(0xFF10B981),
                size: 14),
            const SizedBox(width: 6),
            Text(
              nombreViajero,
              style: TextStyle(
                  color: esAcompanante
                      ? const Color(0xFF1E6BFF)
                      : const Color(0xFF10B981),
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            if (esAcompanante) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E6BFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Acompañante',
                    style: TextStyle(
                        color: Color(0xFF1E6BFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
            if (yaAbordado) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Abordado',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
            if (finalizada) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Finalizado',
                    style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
          const SizedBox(height: 8),

          Row(children: [
            const Icon(Icons.event_seat_rounded,
                color: Color(0xFF6B7280), size: 13),
            const SizedBox(width: 6),
            Text('Asiento $asiento',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            const Icon(Icons.location_on_outlined,
                color: Color(0xFF6B7280), size: 13),
            const SizedBox(width: 4),
            Expanded(
              child: Text(paradero,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 10),

          // Código de verificación — solo si no está finalizado
          if (!finalizada) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF1E6BFF).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('CÓDIGO DE VERIFICACIÓN',
                      style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(codigo,
                      style: const TextStyle(
                          color: Color(0xFF1E6BFF),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6)),
                  const SizedBox(height: 4),
                  const Text('Muéstralo al conductor al abordar',
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Botones acción ───────────────────────────────────────────────
          Row(children: [
            if (finalizada) ...[
              // CP01/CP06 — Botón calificar solo cuando viaje finalizado
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _abrirCalificacion(context, viajeId, doc),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.star_rounded, size: 14),
                  label: const Text('Calificar viaje',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ] else if (enCamino) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _yaBaje(
                      context,
                      doc.id,
                      viajeId,
                      asiento is int
                          ? asiento
                          : int.tryParse(asiento.toString()) ?? 0),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(
                        color: Color(0xFF10B981), width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text('Ya bajé',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ] else ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _cancelarReserva(
                      context,
                      doc.id,
                      viajeId,
                      asiento is int
                          ? asiento
                          : int.tryParse(asiento.toString()) ?? 0),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF3B30),
                    side: const BorderSide(
                        color: Color(0xFFFF3B30), width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 14),
                  label: const Text('Cancelar reserva',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ]),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () =>
                  _reportarIncidencia(context, viajeId, nombreViajero),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9CA3AF),
              ),
              icon: const Icon(Icons.report_problem_outlined, size: 14),
              label: const Text('Reportar incidencia',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: Color(0xFF1F2937), thickness: 0.5),
        ],
      ),
    );
  }
  // ── Abrir pantalla de calificación ───────────────────────────────────────
  Future<void> _abrirCalificacion(
      BuildContext context,
      String viajeId,
      DocumentSnapshot reservaDoc,
      ) async {
    final pasajeroUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // CP03 — Verificar si ya calificó antes de abrir la pantalla
    if (pasajeroUid.isNotEmpty) {
      final yaCalif = await FirebaseFirestore.instance
          .collection('calificaciones')
          .where('viajeId', isEqualTo: viajeId)
          .where('pasajeroUid', isEqualTo: pasajeroUid)
          .limit(1)
          .get();

      if (yaCalif.docs.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ya calificaste este viaje. Solo se permite una calificación por viaje.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ]),
            backgroundColor: const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
        return; // ← bloquea la navegación
      }
    }
    final viajeSnap = await FirebaseFirestore.instance
        .collection('viajes')
        .doc(viajeId)
        .get();

    if (!viajeSnap.exists || !context.mounted) return;

    final vData = viajeSnap.data()!;
    final conductorUid = vData['conductorUid'] ?? '';
    final conductorNombre = vData['conductorNombre'] ?? 'Conductor';
    final rutaLabel = vData['rutaLabel'] ?? '-';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalificacionView(
          viajeId: viajeId,
          conductorUid: conductorUid,
          conductorNombre: conductorNombre,
          rutaLabel: rutaLabel,
        ),
      ),
    );
  }

  Future<void> _yaBaje(BuildContext context, String reservaId,
      String viajeId, int numeroAsiento) async {
    final db = FirebaseFirestore.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Ya bajaste?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Confirma que ya saliste del colectivo.',
            style: TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No',
                  style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, ya bajé',
                  style: TextStyle(color: Color(0xFF10B981)))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final viajeRef = db.collection('viajes').doc(viajeId);
      final reservaRef = db.collection('reservas').doc(reservaId);

      await db.runTransaction((tx) async {
        final snap = await tx.get(viajeRef);
        if (!snap.exists) return;
        final data = snap.data()!;
        final asientosMapa =
        Map<String, dynamic>.from(data['asientos'] ?? {});
        final key = 'asiento_$numeroAsiento';
        asientosMapa[key] = {
          'numero': numeroAsiento,
          'estado': 'libre',
          'pasajero': null
        };
        final ocupadosLista =
        List<int>.from(data['asientosListaOcupados'] ?? []);
        ocupadosLista.remove(numeroAsiento);
        tx.update(viajeRef, {
          'asientos': asientosMapa,
          'asientosListaOcupados': ocupadosLista,
          'asientosOcupados': ocupadosLista.length,
        });
        tx.update(reservaRef, {'estado': 'finalizada'});
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('¡Hasta la próxima! Asiento liberado.'),
            backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFFF3B30)));
      }
    }
  }

  Future<void> _cancelarReserva(BuildContext context, String reservaId,
      String viajeId, int numeroAsiento) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar reserva',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            '¿Deseas cancelar esta reserva? Se liberará el asiento.',
            style: TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No',
                  style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, cancelar',
                  style: TextStyle(color: Color(0xFFFF3B30)))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await bookingService.cancelarReserva(
          reservaId: reservaId,
          viajeId: viajeId,
          numeroAsiento: numeroAsiento,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Reserva cancelada'),
              backgroundColor: Color(0xFF10B981)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFFF3B30)));
        }
      }
    }
  }

  void _abrirMapaModal(BuildContext context, String viajeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.80,
        child: MapaSeguimientoWidget(viajeId: viajeId),
      ),
    );
  }

  void _reportarIncidencia(
      BuildContext context, String viajeId, String nombreViajero) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportarIncidenciaView(
          rolUsuario: 'pasajero',
          viajeId: viajeId,
        ),
      ),
    );
  }
}