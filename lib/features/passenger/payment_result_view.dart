import 'package:flutter/material.dart';
import '../../app_theme.dart';

class PaymentResultView extends StatelessWidget {
  final String status; // 'success', 'pending', 'error'

  const PaymentResultView({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    if (status == 'success') {
      icon = Icons.check_circle_rounded;
      color = CabifyColors.success;
      title = '¡Pago Aprobado!';
      subtitle = 'Tu asiento ha sido reservado exitosamente. Ya puedes ver los detalles en Mis Viajes.';
    } else if (status == 'pending') {
      icon = Icons.hourglass_top_rounded;
      color = Colors.amber;
      title = 'Pago Pendiente';
      subtitle = 'Tu pago se está procesando. Te avisaremos cuando se confirme.';
    } else {
      icon = Icons.error_rounded;
      color = CabifyColors.error;
      title = 'Pago Fallido';
      subtitle = status == 'concurrency_error' 
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
