import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'seat_selection_view.dart';
import 'resumen_reservas_sesion_view.dart';

class PaymentResultView extends StatefulWidget {
  final String status; // 'success', 'pending', 'error'
  final String? viajeId;
  final String? paradero;
  final String? nombrePasajero;
  final String? rutaSeleccionada;

  const PaymentResultView({
    super.key, 
    required this.status,
    this.viajeId,
    this.paradero,
    this.nombrePasajero,
    this.rutaSeleccionada,
  });

  @override
  State<PaymentResultView> createState() => _PaymentResultViewState();
}

class _PaymentResultViewState extends State<PaymentResultView> {
  @override
  void initState() {
    super.initState();
    if (widget.status == 'success') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarDialogoOtroAsiento());
    }
  }

  void _mostrarDialogoOtroAsiento() {
    if (widget.viajeId == null || widget.paradero == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¡Reserva confirmada!', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('¿Deseas reservar otro asiento para alguien más en este mismo viaje?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResumenReservasSesionView(viajeId: widget.viajeId!)));
            },
            child: const Text('NO, FINALIZAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SeatSelectionView(
                viajeId: widget.viajeId!,
                paradero: widget.paradero!,
                nombrePasajero: widget.nombrePasajero,
                rutaSeleccionada: widget.rutaSeleccionada,
              )));
            },
            style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.primary),
            child: const Text('SÍ, RESERVAR OTRO'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    if (widget.status == 'success') {
      icon = Icons.check_circle_rounded;
      color = CabifyColors.success;
      title = '¡Pago Aprobado!';
      subtitle = 'Tu asiento ha sido reservado exitosamente.';
    } else if (widget.status == 'pending') {
      icon = Icons.hourglass_top_rounded;
      color = Colors.amber;
      title = 'Pago Pendiente';
      subtitle = 'Tu pago se está procesando. Te avisaremos cuando se confirme.';
    } else {
      icon = Icons.error_rounded;
      color = CabifyColors.error;
      title = 'Pago Fallido';
      subtitle = widget.status == 'concurrency_error'
        ? 'Lo sentimos, este asiento ya no está disponible. El proceso de pago ha sido anulado.'
        : 'El pago fue rechazado. Verifica los datos de tu tarjeta e inténtalo de nuevo.';
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: color),
              const SizedBox(height: 24),
              Text(title, style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 16),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('VOLVER AL INICIO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
