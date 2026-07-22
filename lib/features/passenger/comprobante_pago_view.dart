import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/booking_service.dart';
import '../../models/comprobante_model.dart';
import '../../app_theme.dart';

class ComprobantePagoView extends StatelessWidget {
  final String reservaId;
  final _bookingService = BookingService();

  ComprobantePagoView({super.key, required this.reservaId});

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
        title: const Text('Comprobante de Pago', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: CabifyColors.primary),
            onPressed: () {
              // Lógica de compartir imagen o PDF en el futuro
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _bookingService.getReservaStream(reservaId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) return const Center(child: Text('Comprobante no encontrado'));
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final model = ComprobanteModel.fromFirestore(data, reservaId);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFF10B981),
                        child: Icon(Icons.check, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 16),
                      const Text('PAGO EXITOSO', 
                        style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(model.montoFormateado, 
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: CabifyColors.textPrimary)),
                      const Divider(height: 48),
                      _rowInfo('Cód. Comprobante', model.codigoComprobante),
                      _rowInfo('Fecha', model.fechaFormateada),
                      _rowInfo('Viajero', model.viajeroNombre),
                      _rowInfo('Conductor', model.conductorNombre),
                      _rowInfo('Vehículo', model.placaVehiculo),
                      _rowInfo('Asiento', 'Asiento ${model.asiento}'),
                      _rowInfo('Paradero', model.paradero),
                      _rowInfo('Código Verif.', model.codigoVerificacion),
                      const Divider(height: 48),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.security, size: 14, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Text('ID TRANSACCIÓN: ${model.paymentId ?? "-"}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('FINALIZAR'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _rowInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          Text(value, style: const TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
