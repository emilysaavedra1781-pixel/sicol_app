import 'package:flutter/material.dart';
import '../widgets/status_banner.dart';
import '../widgets/admin_alert.dart';
import '../widgets/start_button.dart';
import '../widgets/seats_grid.dart';
import '../widgets/legend_item.dart';

class TripTab extends StatelessWidget {
  final Map<String, dynamic> viaje;
  final bool enCamino;
  final bool forzado;
  final String rutaLabel;
  final int capacidad;
  final int asientosOcupados;
  final Map<String, dynamic> asientos;
  final bool llegoAlDestino;
  final bool todosAbordaron;
  final int pendientes;
  final bool arrancando;
  final bool cerrando;
  final VoidCallback onArrancar;
  final VoidCallback onVerificar;
  final VoidCallback onTerminar;

  const TripTab({
    super.key,
    required this.viaje,
    required this.enCamino,
    required this.forzado,
    required this.rutaLabel,
    required this.capacidad,
    required this.asientosOcupados,
    required this.asientos,
    required this.llegoAlDestino,
    required this.todosAbordaron,
    required this.pendientes,
    required this.arrancando,
    required this.cerrando,
    required this.onArrancar,
    required this.onVerificar,
    required this.onTerminar,
  });

  @override
  Widget build(BuildContext context) {
    final estaLleno = asientosOcupados >= capacidad;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          statusBanner(
            enCamino: enCamino,
            rutaLabel: rutaLabel,
            asientosOcupados: asientosOcupados,
            capacidad: capacidad,
          ),
          const SizedBox(height: 16),
          if (forzado && enCamino) ...[
            adminAlert(),
            const SizedBox(height: 16),
          ],
          if (!enCamino) ...[
            startButton(
              estaLleno: estaLleno,
              asientosOcupados: asientosOcupados,
              capacidad: capacidad,
              todosAbordaron: todosAbordaron,
              pendientes: pendientes,
              arrancando: arrancando,
              onArrancar: onArrancar,
              onVerificar: onVerificar,
            ),
            const SizedBox(height: 20),
          ],
          const Text('Asientos',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          seatsGrid(asientos: asientos, capacidad: capacidad),
          const SizedBox(height: 8),
          Row(children: [
            legendItem(const Color(0xFF6B7280), 'Libre'),
            const SizedBox(width: 16),
            legendItem(const Color(0xFFF59E0B), 'Ocupado'),
            const SizedBox(width: 16),
            legendItem(const Color(0xFF10B981), 'Abordado'),
            const SizedBox(width: 16),
            legendItem(const Color(0xFFFF3B30), 'Bloqueado'),
          ]),
          const SizedBox(height: 32),
          if (enCamino) ...[
            if (!llegoAlDestino)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'El botón se habilitará al llegar al destino final.',
                          style:
                          TextStyle(color: Color(0xFFF59E0B), fontSize: 12))),
                ]),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (cerrando || !llegoAlDestino) ? null : onTerminar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  disabledBackgroundColor: const Color(0xFF374151),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFF6B7280),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: cerrando
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : Icon(
                    !llegoAlDestino
                        ? Icons.lock_outline_rounded
                        : Icons.flag_rounded,
                    size: 20),
                label: Text(
                  cerrando
                      ? 'Terminando...'
                      : !llegoAlDestino
                      ? 'Terminar viaje (en ruta...)'
                      : 'Terminar viaje',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}