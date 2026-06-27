import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/trip_service.dart';
import '../../services/simulation_service.dart';
import '../../services/location_service.dart';
import 'constants/route_data.dart';
import 'tabs/trip_tab.dart';
import 'tabs/map_tab.dart';
import 'tabs/passengers_tab.dart';

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

class _DriverTripViewState extends State<DriverTripView>
    with SingleTickerProviderStateMixin {
  final _tripService = TripService();
  final _simService = SimulationService();
  final _locationService = LocationService();
  late TabController _tabController;
  GoogleMapController? _mapController;

  bool _cerrando = false;
  bool _arrancando = false;
  bool _yaNotificado = false;
  bool _forzadoNotificado = false;
  bool _simulacionIniciada = false; // ← fix reinicio de simulación
  bool _todosBajaron = false;       // ← nuevo: controla botón terminar viaje

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _simService.detenerSimulacion();
    _tabController.dispose();
    final ctrl = _mapController;
    _mapController = null;
    ctrl?.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool _todosAbordaron(Map<String, dynamic> asientos) {
    final conPasajero = asientos.values.where((a) {
      final s = (a as Map?)?.cast<String, dynamic>() ?? {};
      return s['estado'] == 'ocupado' || s['estado'] == 'abordado';
    }).toList();
    if (conPasajero.isEmpty) return false;
    return conPasajero.every(
            (a) => (a as Map).cast<String, dynamic>()['estado'] == 'abordado');
  }

  int _contarPendientes(Map<String, dynamic> asientos) {
    return asientos.values.where((a) {
      final s = (a as Map?)?.cast<String, dynamic>() ?? {};
      return s['estado'] == 'ocupado';
    }).length;
  }

  // ── Acciones ─────────────────────────────────────────────────────────────

  Future<void> _arrancarColectivo(Map<String, dynamic> viaje) async {
    final asientosOcupados =
        (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
    final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 4;
    final asientos =
        (viaje['asientos'] as Map?)?.cast<String, dynamic>() ?? {};
    final estaLleno = asientosOcupados >= capacidad;
    final pendientes = _contarPendientes(asientos);
    final forzado = viaje['forzadoPorAdmin'] == true;

    if (!forzado && (!estaLleno || pendientes > 0)) return;

    setState(() => _arrancando = true);
    try {
      await _tripService.arrancarColectivo(widget.viajeId);
      final ruta = viaje['ruta'] ?? 'chosica_lima';
      _simulacionIniciada = true;
      _simService.iniciarSimulacion(widget.viajeId, ruta);
      _tabController.animateTo(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFFF3B30)));
      }
    } finally {
      if (mounted) setState(() => _arrancando = false);
    }
  }

  Future<void> _terminarViaje(String ruta) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terminar viaje',
            style: TextStyle(color: Colors.white)),
        content: const Text('¿Confirmas que llegaste al destino?',
            style: TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF6B7280)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0),
            child: const Text('Sí, terminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // ── RF34: Verificación de GPS antes de finalizar ─────────────────
      try {
        final verificacion = await _locationService
            .verificarUbicacionParaFinalizarViaje(ruta);

        if (!verificacion.dentroDelRango) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Estás a ${verificacion.distanciaMetros.toStringAsFixed(0)}m del destino. Debes estar a menos de 200m para terminar el viaje.'),
                backgroundColor: const Color(0xFFFF3B30),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return; // bloquea el cierre del viaje
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: const Color(0xFFFF3B30),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      setState(() => _cerrando = true);
      try {
        _simulacionIniciada = false;
        _simService.detenerSimulacion();
        await _tripService.cerrarViaje(widget.viajeId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          setState(() => _cerrando = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFFF3B30)));
        }
      }
    }
  }

  Future<void> _validarPasajero(
      Map<String, dynamic> pasajero, int numeroAsiento) async {
    final codigoController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.qr_code_scanner_rounded,
              color: Color(0xFF1E6BFF), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Validar — Asiento $numeroAsiento',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pasajero['nombre'] ?? '-',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Paradero: ${pasajero['paradero'] ?? '-'}',
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: 16),
            const Text('Ingresa el código del pasajero:',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: codigoController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                  color: Color(0xFF1E6BFF),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6),
              textAlign: TextAlign.center,
              maxLength: 5,
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF0A0E1A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF1E6BFF), width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF1E6BFF), width: 2)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF1F2937), width: 1)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF6B7280)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E6BFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0),
            child: const Text('Verificar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final codigoIngresado = codigoController.text.trim().toUpperCase();

    try {
      final reservaQuery = await FirebaseFirestore.instance
          .collection('reservas')
          .where('viajeId', isEqualTo: widget.viajeId)
          .where('numeroAsiento', isEqualTo: numeroAsiento)
          .where('estado', isEqualTo: 'confirmada')
          .limit(1)
          .get();

      if (reservaQuery.docs.isEmpty) {
        _mostrarResultadoValidacion(false, 'No se encontró reserva');
        return;
      }

      final reserva =
      reservaQuery.docs.first.data() as Map<String, dynamic>;
      final codigoCorrecto =
      (reserva['codigoVerificacion'] ?? '').toString().toUpperCase();

      if (codigoIngresado == codigoCorrecto) {
        await reservaQuery.docs.first.reference
            .update({'estado': 'abordado'});
        await FirebaseFirestore.instance
            .collection('viajes')
            .doc(widget.viajeId)
            .update({
          'asientos.asiento_$numeroAsiento.estado': 'abordado',
        });
        _mostrarResultadoValidacion(true, pasajero['nombre'] ?? '');
      } else {
        _mostrarResultadoValidacion(false, 'Código incorrecto');
      }
    } catch (e) {
      _mostrarResultadoValidacion(false, 'Error: $e');
    }
  }

  void _mostrarResultadoValidacion(bool exito, String mensaje) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                exito
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: exito
                    ? const Color(0xFF10B981)
                    : const Color(0xFFFF3B30),
                size: 56),
            const SizedBox(height: 12),
            Text(exito ? '¡Pasajero verificado!' : 'Código inválido',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(exito ? '$mensaje ha abordado' : mensaje,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: exito
                      ? const Color(0xFF10B981)
                      : const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0),
              child: const Text('Aceptar'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _tripService.getViajeStream(widget.viajeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              backgroundColor: Color(0xFF0A0E1A),
              body: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF1E6BFF))));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
              backgroundColor: Color(0xFF0A0E1A),
              body: Center(
                  child: Text('Viaje no encontrado',
                      style: TextStyle(color: Colors.white))));
        }

        final viaje = snapshot.data!.data() as Map<String, dynamic>;
        final estado = viaje['estado'] ?? 'activo';
        final enCamino = estado == 'en_camino';
        final forzado = viaje['forzadoPorAdmin'] == true;
        final ruta = viaje['ruta'] ?? 'chosica_lima';
        final rutaLabel = viaje['rutaLabel'] ?? '';
        final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 4;
        final asientosOcupados =
            (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
        final asientos =
            (viaje['asientos'] as Map?)?.cast<String, dynamic>() ?? {};
        final ubicacion =
        (viaje['ubicacionActual'] as Map?)?.cast<String, dynamic>();
        final todosAbordaron = _todosAbordaron(asientos);
        final pendientes = _contarPendientes(asientos);

        // ── Verificar si todos los pasajeros bajaron ──────────────────────
        if (enCamino) {
          _tripService.todosBajaron(widget.viajeId).then((valor) {
            if (mounted && _todosBajaron != valor) {
              setState(() => _todosBajaron = valor);
            }
          });
        }

        // llegoAlDestino ahora depende de que todos los pasajeros hayan bajado
        final llegoAlDestino = enCamino && _todosBajaron;

        // ── Notificación luz verde del admin ─────────────────────────────
        if (forzado && !enCamino && !_forzadoNotificado) {
          _forzadoNotificado = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF111827),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.flash_on,
                        color: Color(0xFFF59E0B), size: 22),
                    SizedBox(width: 8),
                    Text('¡Luz verde del admin!',
                        style: TextStyle(
                            color: Colors.white, fontSize: 16)),
                  ],
                ),
                content: const Text(
                  'El administrador autorizó la salida. Puedes arrancar el viaje aunque el colectivo no esté lleno.',
                  style: TextStyle(
                      color: Color(0xFF6B7280), fontSize: 14),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            );
          });
        }

        if (enCamino) _forzadoNotificado = false;

        // ── Notificación colectivo lleno ─────────────────────────────────
        if (!enCamino && asientosOcupados >= capacidad && !_yaNotificado) {
          _yaNotificado = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¡Colectivo lleno! Valida los códigos de cada pasajero antes de arrancar.',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                backgroundColor: const Color(0xFF111827),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                      color: Color(0xFF10B981), width: 1),
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          });
        }

        if (asientosOcupados < capacidad) _yaNotificado = false;

        // ── Iniciar simulación solo una vez ──────────────────────────────
        if (enCamino && !_simulacionIniciada) {
          _simulacionIniciada = true;
          if (_simService.estaDetenido) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _simService.iniciarSimulacion(widget.viajeId, ruta);
            });
          }
        }

        if (enCamino && ubicacion != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final ctrl = _mapController;
            if (ctrl == null) return;
            final lat = (ubicacion['lat'] as num?)?.toDouble() ?? 0;
            final lng = (ubicacion['lng'] as num?)?.toDouble() ?? 0;
            try {
              ctrl.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
            } catch (_) {}
          });
        }

        final pasajeros = asientos.values
            .where((a) {
          final s = (a as Map?)?.cast<String, dynamic>() ?? {};
          return (s['estado'] == 'ocupado' ||
              s['estado'] == 'abordado') &&
              s['pasajero'] != null;
        })
            .map((a) =>
            ((a as Map).cast<String, dynamic>()['pasajero'] as Map)
                .cast<String, dynamic>())
            .toList();

        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF111827),
            elevation: 0,
            leading: const SizedBox(),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rutaLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Row(children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: enCamino
                              ? const Color(0xFF1E6BFF)
                              : const Color(0xFF10B981),
                          shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(
                      enCamino ? 'En camino' : 'Esperando pasajeros',
                      style: TextStyle(
                          color: enCamino
                              ? const Color(0xFF1E6BFF)
                              : const Color(0xFF10B981),
                          fontSize: 11)),
                ]),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF1E6BFF),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF6B7280),
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(
                    icon: Icon(Icons.dashboard_rounded, size: 18),
                    text: 'Viaje'),
                Tab(icon: Icon(Icons.map_rounded, size: 18), text: 'Mapa'),
                Tab(
                    icon: Icon(Icons.people_rounded, size: 18),
                    text: 'Pasajeros'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              TripTab(
                viaje: viaje,
                enCamino: enCamino,
                forzado: forzado,
                rutaLabel: rutaLabel,
                capacidad: capacidad,
                asientosOcupados: asientosOcupados,
                asientos: asientos,
                llegoAlDestino: llegoAlDestino,
                todosAbordaron: todosAbordaron,
                pendientes: pendientes,
                arrancando: _arrancando,
                cerrando: _cerrando,
                onArrancar: () => _arrancarColectivo(viaje),
                onVerificar: () => _tabController.animateTo(2),
                onTerminar: () => _terminarViaje(ruta),
              ),
              MapTab(
                enCamino: enCamino,
                ubicacion: ubicacion,
                ruta: ruta,
                onMapCreated: (c) => _mapController = c,
                onIrAViaje: () => _tabController.animateTo(0),
              ),
              PassengersTab(
                viajeId: widget.viajeId,
                pasajeros: pasajeros,
                capacidad: capacidad,
                enCamino: enCamino,
                onValidar: _validarPasajero,
              ),
            ],
          ),
        );
      },
    );
  }
}