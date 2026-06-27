import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/trip_service.dart';
import 'driver_drawer.dart';

/// RF37 — Reporte de Ingresos del Conductor por Viaje
class DriverIngresosView extends StatefulWidget {
  const DriverIngresosView({super.key});

  @override
  State<DriverIngresosView> createState() => _DriverIngresosViewState();
}

class _DriverIngresosViewState extends State<DriverIngresosView> {
  final _tripService = TripService();

  DateTimeRange? _rangoFechas;

  static const int _precioPasaje = 15;
  static const int _montoConductor = 10;

  Future<void> _seleccionarRango() async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year - 1),
      lastDate: ahora,
      initialDateRange: _rangoFechas,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF1E6BFF),
            surface: Color(0xFF111827),
          ),
        ),
        child: child!,
      ),
    );
    if (rango != null) {
      setState(() => _rangoFechas = rango);
    }
  }

  void _limpiarFiltro() {
    setState(() => _rangoFechas = null);
  }

  bool _dentroDelRango(Map<String, dynamic> viaje) {
    if (_rangoFechas == null) return true;
    final cerradoEn = viaje['cerradoEn'];
    if (cerradoEn is! Timestamp) return false;
    final fecha = cerradoEn.toDate();
    final desde = DateTime(_rangoFechas!.start.year, _rangoFechas!.start.month,
        _rangoFechas!.start.day);
    final hasta = DateTime(_rangoFechas!.end.year, _rangoFechas!.end.month,
        _rangoFechas!.end.day, 23, 59, 59);
    return fecha.isAfter(desde.subtract(const Duration(seconds: 1))) &&
        fecha.isBefore(hasta.add(const Duration(seconds: 1)));
  }

  int _pasajerosDeViaje(Map<String, dynamic> viaje) {
    // Se cuenta por reservas confirmadas/abordadas/finalizadas asociadas al viaje,
    // pero como ya está cerrado usamos asientosOcupados al momento del cierre.
    return (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      drawer: const DriverDrawer(currentRoute: 'ingresos'),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('Mis ingresos',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined,
                color: Color(0xFF1E6BFF)),
            tooltip: 'Filtrar por fecha',
            onPressed: _seleccionarRango,
          ),
          if (_rangoFechas != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
              tooltip: 'Quitar filtro',
              onPressed: _limpiarFiltro,
            ),
        ],
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
              child: Text('Error al cargar ingresos: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white)),
            );
          }

          final todos = snapshot.data ?? [];
          final viajes = todos.where(_dentroDelRango).toList();

          // EA01 — Sin ingresos registrados: totales en cero, sin error.
          int totalPasajeros = 0;
          int montoTotalGeneral = 0;
          int montoConductorGeneral = 0;
          for (final v in viajes) {
            final n = _pasajerosDeViaje(v);
            totalPasajeros += n;
            montoTotalGeneral += n * _precioPasaje;
            montoConductorGeneral += n * _montoConductor;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_rangoFechas != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E6BFF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF1E6BFF)
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded,
                            color: Color(0xFF1E6BFF), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_fmt(_rangoFechas!.start)} — ${_fmt(_rangoFechas!.end)}',
                            style: const TextStyle(
                                color: Color(0xFF1E6BFF), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Resumen general ───────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E6BFF), Color(0xFF0A4BCC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total recibido',
                          style: TextStyle(
                              color: Color(0xFFBFD7FF), fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('S/ $montoConductorGeneral.00',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _miniStat('Viajes', '${viajes.length}'),
                          const SizedBox(width: 20),
                          _miniStat('Pasajeros', '$totalPasajeros'),
                          const SizedBox(width: 20),
                          _miniStat('Recaudado',
                              'S/ $montoTotalGeneral'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  viajes.isEmpty
                      ? 'Sin ingresos registrados'
                      : 'Detalle por viaje',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                // EA01 — mensaje informativo si no hay ingresos
                if (viajes.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.payments_outlined,
                            color: Color(0xFF6B7280), size: 40),
                        SizedBox(height: 10),
                        Text(
                          'Aún no tienes ingresos registrados en este periodo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  ...viajes.map((v) => _viajeCard(v)),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(color: Color(0xFFBFD7FF), fontSize: 11)),
      ],
    );
  }

  Widget _viajeCard(Map<String, dynamic> viaje) {
    final n = _pasajerosDeViaje(viaje);
    final montoTotal = n * _precioPasaje;
    final montoConductor = n * _montoConductor;
    final rutaLabel = viaje['rutaLabel'] ?? 'Sin ruta';
    final cerradoEn = viaje['cerradoEn'];
    final fechaTexto =
    cerradoEn is Timestamp ? _fmt(cerradoEn.toDate()) : '-';

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
              Icon(Icons.people_outline,
                  color: const Color(0xFF6B7280), size: 14),
              const SizedBox(width: 6),
              Text('$n pasajero(s)',
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 12)),
              const Spacer(),
              Text('Total: S/ $montoTotal',
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.payments_rounded,
                    color: Color(0xFF10B981), size: 14),
                const SizedBox(width: 6),
                Text('Tu ingreso: S/ $montoConductor',
                    style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}