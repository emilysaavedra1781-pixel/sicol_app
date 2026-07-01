import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/booking_service.dart';
import 'calificacion_view.dart';
import 'reserva_detalle_view.dart';
import 'comprobante_pago_view.dart';
import '../../app_theme.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('MIS VIAJES'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          // CP01: Lista ordenada de más reciente a más antigua
          stream: db
              .collection('reservas')
              .where('pasajeroUid', isEqualTo: uid)
              .orderBy('creadoEn', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final reservas = snapshot.data!.docs;

            if (reservas.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.confirmation_number_outlined, color: Colors.grey[300], size: 64),
                    const SizedBox(height: 16),
                    Text('No tienes viajes registrados', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reservas.length,
              itemBuilder: (ctx, i) {
                final doc = reservas[i];
                final data = doc.data() as Map<String, dynamic>;
                return _buildReservaCard(context, doc.id, data);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildReservaCard(BuildContext context, String reservaId, Map<String, dynamic> data) {
    final db = FirebaseFirestore.instance;
    final viajeId = data['viajeId'] ?? '';
    final fecha = (data['creadoEn'] as Timestamp?)?.toDate() ?? DateTime.now();
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
    final estado = data['estado'] ?? 'confirmada';
    final monto = (data['monto'] as num?)?.toDouble() ?? 15.0;

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('viajes').doc(viajeId).snapshots(),
      builder: (context, viajeSnap) {
        final vData = viajeSnap.hasData && viajeSnap.data!.exists 
            ? (viajeSnap.data!.data() as Map<String, dynamic>) 
            : <String, dynamic>{};
        
        final conductorNombre = vData['conductorNombre'] ?? 'Sicol Conductor';
        final placa = vData['vehiculo']?['placa'] ?? '-';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () {
              // CP02: Detalle al tocar
              Navigator.push(context, MaterialPageRoute(builder: (_) => ReservaDetalleView(
                reservaId: reservaId,
                codigo: data['codigoVerificacion'] ?? '-----',
                nombrePasajero: data['nombreViajero'] ?? 'Pasajero',
              )));
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conductorNombre,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      _buildEstadoBadge(estado),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Placa: $placa', style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 13)),
                  const Divider(height: 24),
                  _infoRow(Icons.event_seat, 'Asiento ${data['numeroAsiento']}'),
                  const SizedBox(height: 4),
                  _infoRow(Icons.location_on_outlined, data['paradero'] ?? '-'),
                  const SizedBox(height: 4),
                  _infoRow(Icons.calendar_today_outlined, formatoFecha.format(fecha)),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'S/ ${monto.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: CabifyColors.primary, fontSize: 16),
                      ),
                      Row(
                        children: [
                          if (estado != 'cancelada')
                            TextButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ComprobantePagoView(reservaId: reservaId)));
                              },
                              child: const Text('COMPROBANTE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          if (estado == 'finalizada')
                            TextButton(
                              onPressed: () => _irACalificar(context, viajeId, reservaId, vData),
                              child: const Text('CALIFICAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          if (estado == 'confirmada')
                            TextButton(
                              onPressed: () => _intentarCancelarReserva(context, reservaId, viajeId, data['numeroAsiento'], vData['estado']),
                              style: TextButton.styleFrom(foregroundColor: CabifyColors.error),
                              child: const Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _intentarCancelarReserva(BuildContext context, String reservaId, String viajeId, int numAsiento, String? estadoViaje) async {
    // CP03: Bloqueo si el colectivo ya arrancó
    if (estadoViaje == 'en_camino' || estadoViaje == 'finalizado') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes cancelar esta reserva porque el viaje ya ha comenzado.'),
          backgroundColor: CabifyColors.error,
        ),
      );
      return;
    }

    // CP01: Advertencia de no devolución
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar cancelación'),
        content: const Text(
          '¿Estás seguro? No se realizan devoluciones.',
          style: TextStyle(fontWeight: FontWeight.w600, color: CabifyColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // CP02: Volver
            child: const Text('VOLVER', style: TextStyle(color: CabifyColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CabifyColors.error, 
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 40),
            ),
            child: const Text('CONFIRMAR CANCELACIÓN'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (confirmar == true) {
      try {
        await bookingService.cancelarReserva(
          reservaId: reservaId,
          viajeId: viajeId,
          numeroAsiento: numAsiento,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reserva cancelada correctamente.'), backgroundColor: CabifyColors.success),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: CabifyColors.error),
          );
        }
      }
    }
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: CabifyColors.textSecondary),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13, color: CabifyColors.textPrimary)),
      ],
    );
  }

  Widget _buildEstadoBadge(String estado) {
    Color color;
    String text = estado.toUpperCase();

    switch (estado) {
      case 'confirmada':
        color = const Color(0xFF10B981);
        text = 'CONFIRMADA';
        break;
      case 'abordado':
        color = CabifyColors.primary;
        text = 'EN CURSO';
        break;
      case 'finalizada':
      case 'calificada':
        color = const Color(0xFF6B7280);
        text = 'FINALIZADA';
        break;
      case 'cancelada':
        color = CabifyColors.error;
        text = 'CANCELADA';
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _irACalificar(BuildContext context, String viajeId, String reservaId, Map<String, dynamic> v) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CalificacionView(
      viajeId: viajeId,
      reservaId: reservaId,
      conductorUid: v['conductorUid'] ?? '',
      conductorNombre: v['conductorNombre'] ?? 'Conductor',
      rutaLabel: v['rutaLabel'] ?? '-',
    )));
  }
}
