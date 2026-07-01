import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cambiar_paradero_view.dart';
import 'conductor_public_perfil_view.dart';
import 'comprobante_pago_view.dart';
import '../../app_theme.dart';

class ReservaDetalleView extends StatelessWidget {
  final String reservaId;
  final String codigo;
  final String nombrePasajero;

  const ReservaDetalleView({
    super.key,
    required this.reservaId,
    required this.codigo,
    required this.nombrePasajero,
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
        title: const Text('Detalle de Reserva', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: db.collection('reservas').doc(reservaId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists) return const Center(child: Text('La reserva no existe.'));
          
          final res = snap.data!.data() as Map<String, dynamic>;
          final viajeId = res['viajeId'] ?? '';
          final monto = (res['monto'] as num?)?.toDouble() ?? 15.0;

          return StreamBuilder<DocumentSnapshot>(
            stream: viajeId.isNotEmpty ? db.collection('viajes').doc(viajeId).snapshots() : const Stream.empty(),
            builder: (context, viajeSnap) {
              final vData = viajeSnap.hasData && viajeSnap.data!.exists 
                  ? (viajeSnap.data!.data() as Map<String, dynamic>) 
                  : <String, dynamic>{};

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resumen visual superior
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: CabifyColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text('CÓDIGO DE ACCESO', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                          const SizedBox(height: 8),
                          Text(codigo, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 6)),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _headerItem('Asiento', res['numeroAsiento']?.toString() ?? '-'),
                              _headerItem('Monto', 'S/ ${monto.toStringAsFixed(2)}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    _sectionTitle('DATOS DEL VIAJE'),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildDetail('Conductor', vData['conductorNombre'] ?? 'Sicol Conductor'),
                            const Divider(),
                            _buildDetail('Vehículo', '${vData['vehiculo']?['marca'] ?? ''} - ${vData['vehiculo']?['placa'] ?? ''}'),
                            const Divider(),
                            _buildDetail('Ruta', vData['rutaLabel'] ?? 'Ruta SICOL'),
                            const Divider(),
                            _buildDetail('Paradero', res['paradero'] ?? '-'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _sectionTitle('PASAJERO'),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildDetail('Nombre', res['nombreViajero'] ?? nombrePasajero),
                            const Divider(),
                            _buildDetail('Estado', (res['estado'] ?? 'confirmada').toString().toUpperCase()),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // CP02: Botón Ver comprobante
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ComprobantePagoView(reservaId: reservaId)));
                        },
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('VER COMPROBANTE DE PAGO'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (vData['conductorUid'] != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ConductorPublicPerfilView(
                                  conductorUid: vData['conductorUid'],
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_outline_rounded),
                          label: const Text('PERFIL DEL CONDUCTOR'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CabifyColors.primary,
                            side: const BorderSide(color: CabifyColors.primary),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _buildCambiarParaderoButton(context, res as Map<String, dynamic>, vData as Map<String, dynamic>),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: CabifyColors.textSecondary, letterSpacing: 1));
  }

  Widget _headerItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildCambiarParaderoButton(BuildContext context, Map<String, dynamic> res, Map<String, dynamic> viaje) {
    final bool yaInicio = viaje['estado'] == 'en_camino' || viaje['estado'] == 'finalizado';
    
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: yaInicio ? null : () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => CambiarParaderoView(
                reservaId: reservaId,
                viajeId: res['viajeId'],
                currentParadero: res['paradero'],
                ruta: res['ruta'],
                numeroAsiento: (res['numeroAsiento'] as num).toInt(),
              )));
            },
            icon: const Icon(Icons.edit_location_alt, size: 18),
            label: const Text('CAMBIAR PUNTO DE RECOJO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        if (yaInicio)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'El viaje ya inició, no es posible cambiar el paradero',
              style: TextStyle(color: CabifyColors.error, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CabifyColors.textSecondary)),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
