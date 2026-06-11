import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/trip_service.dart';
import '../../services/simulation_service.dart';

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
  late TabController _tabController;
  GoogleMapController? _mapController;

  bool _cerrando = false;
  bool _arrancando = false;

  static const List<LatLng> _rutaChosicaLima = [
    LatLng(-11.9347, -76.6952),
    LatLng(-11.9280, -76.6750),
    LatLng(-11.9100, -76.6300),
    LatLng(-11.8900, -76.5800),
    LatLng(-11.9050, -76.9900),
    LatLng(-12.0200, -76.9500),
    LatLng(-12.0400, -76.9800),
    LatLng(-12.0650, -77.0000),
    LatLng(-12.0850, -77.0200),
    LatLng(-12.0900, -77.0350),
    LatLng(-12.0950, -77.0450),
  ];

  static const LatLng _destinoChosicaLima = LatLng(-12.0950, -77.0450);
  static const LatLng _destinoLimaChosica = LatLng(-11.9347, -76.6952);
  static const double _umbralLlegada = 0.005;

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

  bool _haLlegadoAlDestino(Map<String, dynamic>? ubicacion, String ruta) {
    if (ubicacion == null) return false;
    final lat = (ubicacion['lat'] as num?)?.toDouble() ?? 0;
    final lng = (ubicacion['lng'] as num?)?.toDouble() ?? 0;
    final destino = ruta == 'chosica_lima'
        ? _destinoChosicaLima
        : _destinoLimaChosica;
    final dLat = (lat - destino.latitude).abs();
    final dLng = (lng - destino.longitude).abs();
    return dLat < _umbralLlegada && dLng < _umbralLlegada;
  }

  Future<void> _arrancarColectivo(Map<String, dynamic> viaje) async {
    final asientosOcupados = (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
    final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 4;
    final estaLleno = asientosOcupados >= capacidad;

    if (!estaLleno) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) =>
            AlertDialog(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Arrancar con asientos vacios?',
                  style: TextStyle(color: Colors.white)),
              content: Text(
                  'Tienes $asientosOcupados de $capacidad asientos ocupados. Deseas arrancar de todas formas?',
                  style: const TextStyle(color: Color(0xFF6B7280))),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar',
                        style: TextStyle(color: Color(0xFF6B7280)))),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0),
                  child: const Text('Si, arrancar'),
                ),
              ],
            ),
      );
      if (confirm != true) return;
    }

    setState(() => _arrancando = true);
    try {
      await _tripService.arrancarColectivo(widget.viajeId);
      final ruta = viaje['ruta'] ?? 'chosica_lima';
      _simService.iniciarSimulacion(widget.viajeId, ruta);
      _tabController.animateTo(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'),
                backgroundColor: const Color(0xFFFF3B30)));
      }
    } finally {
      if (mounted) setState(() => _arrancando = false);
    }
  }

  Future<void> _terminarViaje() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text(
                'Terminar viaje', style: TextStyle(color: Colors.white)),
            content: const Text('Confirmas que llegaste al destino?',
                style: TextStyle(color: Color(0xFF6B7280))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                      'Cancelar', style: TextStyle(color: Color(0xFF6B7280)))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0),
                child: const Text('Si, terminar'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      setState(() => _cerrando = true);
      try {
        _simService.detenerSimulacion();
        await _tripService.cerrarViaje(widget.viajeId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          setState(() => _cerrando = false);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'),
                  backgroundColor: const Color(0xFFFF3B30)));
        }
      }
    }
  }

  Future<void> _validarPasajero(Map<String, dynamic> pasajero,
      int numeroAsiento,) async {
    final codigoController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF1E6BFF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Validar — Asiento $numeroAsiento',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pasajero['nombre'] ?? '-',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Paradero: ${pasajero['paradero'] ?? '-'}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ingresa el codigo del pasajero:',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codigoController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: Color(0xFF1E6BFF),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                  textAlign: TextAlign.center,
                  maxLength: 5,
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF0A0E1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1E6BFF),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1E6BFF),
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1F2937),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text('Verificar'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final codigoIngresado =
    codigoController.text.trim().toUpperCase();

    try {
      final reservaQuery = await FirebaseFirestore.instance
          .collection('reservas')
          .where('viajeId', isEqualTo: widget.viajeId)
          .where('numeroAsiento', isEqualTo: numeroAsiento)
          .where('estado', isEqualTo: 'confirmada')
          .limit(1)
          .get();

      if (reservaQuery.docs.isEmpty) {
        _mostrarResultadoValidacion(
          false,
          'No se encontro reserva',
        );
        return;
      }

      final reserva =
      reservaQuery.docs.first.data() as Map<String, dynamic>;

      final codigoCorrecto =
      (reserva['codigoVerificacion'] ?? '')
          .toString()
          .toUpperCase();

      if (codigoIngresado == codigoCorrecto) {
        await reservaQuery.docs.first.reference.update({
          'estado': 'abordado',
        });

        await FirebaseFirestore.instance
            .collection('viajes')
            .doc(widget.viajeId)
            .update({
          'asientos.asiento_$numeroAsiento.estado': 'abordado',
        });

        _mostrarResultadoValidacion(
          true,
          pasajero['nombre'] ?? '',
        );
      } else {
        _mostrarResultadoValidacion(
          false,
          'Codigo incorrecto',
        );
      }
    } catch (e) {
      _mostrarResultadoValidacion(
        false,
        'Error: $e',
      );
    }
  }

  void _mostrarResultadoValidacion(bool exito, String mensaje) {
    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(exito ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: exito ? const Color(0xFF10B981) : const Color(
                        0xFFFF3B30), size: 56),
                const SizedBox(height: 12),
                Text(exito ? 'Pasajero verificado!' : 'Codigo invalido',
                    style: const TextStyle(color: Colors.white,
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
              Center(child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                    backgroundColor: exito
                        ? const Color(0xFF10B981)
                        : const Color(0xFFFF3B30),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)), elevation: 0),
                child: const Text('Aceptar'),
              )),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _tripService.getViajeStream(widget.viajeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Color(0xFF0A0E1A),
              body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF1E6BFF))));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(backgroundColor: Color(0xFF0A0E1A),
              body: Center(child: Text('Viaje no encontrado',
                  style: TextStyle(color: Colors.white))));
        }

        final viaje = snapshot.data!.data() as Map<String, dynamic>;
        final estado = viaje['estado'] ?? 'activo';
        final enCamino = estado == 'en_camino';
        final forzado = viaje['forzadoPorAdmin'] == true;
        final ruta = viaje['ruta'] ?? 'chosica_lima';
        final rutaLabel = viaje['rutaLabel'] ?? '';
        final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 4;
        final asientosOcupados = (viaje['asientosOcupados'] as num?)?.toInt() ??
            0;
        final asientos = (viaje['asientos'] as Map?)?.cast<String, dynamic>() ??
            {};
        final ubicacion = (viaje['ubicacionActual'] as Map?)?.cast<
            String,
            dynamic>();
        final llegoAlDestino = enCamino && _haLlegadoAlDestino(ubicacion, ruta);

        if (enCamino && _simService.estaDetenido) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _simService.iniciarSimulacion(widget.viajeId, ruta);
          });
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
          final asiento =
              (a as Map?)?.cast<String, dynamic>() ?? {};

          return (asiento['estado'] == 'ocupado' ||
              asiento['estado'] == 'abordado') &&
              asiento['pasajero'] != null;
        })
            .map((a) =>
            ((a as Map).cast<String, dynamic>()['pasajero']
            as Map)
                .cast<String, dynamic>())
            .toList();

        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF111827),
            elevation: 0,
            leading: const SizedBox(),
            title: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rutaLabel, style: const TextStyle(color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
              Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(
                    color: enCamino ? const Color(0xFF1E6BFF) : const Color(
                        0xFF10B981), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(enCamino ? 'En camino' : 'Esperando pasajeros',
                    style: TextStyle(
                        color: enCamino ? const Color(0xFF1E6BFF) : const Color(
                            0xFF10B981), fontSize: 11)),
              ]),
            ]),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF1E6BFF),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF6B7280),
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_rounded, size: 18),
                    text: 'Viaje'),
                Tab(icon: Icon(Icons.map_rounded, size: 18), text: 'Mapa'),
                Tab(icon: Icon(Icons.people_rounded, size: 18),
                    text: 'Pasajeros'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _tabViaje(viaje: viaje,
                  enCamino: enCamino,
                  forzado: forzado,
                  rutaLabel: rutaLabel,
                  capacidad: capacidad,
                  asientosOcupados: asientosOcupados,
                  asientos: asientos,
                  llegoAlDestino: llegoAlDestino),
              _tabMapa(enCamino: enCamino, ubicacion: ubicacion, ruta: ruta),
              _tabPasajeros(pasajeros: pasajeros,
                  capacidad: capacidad,
                  enCamino: enCamino),
            ],
          ),
        );
      },
    );
  }

  Widget _tabViaje({required Map<String,
      dynamic> viaje, required bool enCamino, required bool forzado,
    required String rutaLabel, required int capacidad, required int asientosOcupados,
    required Map<String, dynamic> asientos, required bool llegoAlDestino}) {
    final estaLleno = asientosOcupados >= capacidad;
    final hayPasajerosPendientes = asientos.values.any((a) {
      final asiento = (a as Map).cast<String, dynamic>();

      return asiento['estado'] == 'ocupado' ||
          asiento['estado'] == 'abordado';
    });
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _bannerEstado(enCamino: enCamino,
            rutaLabel: rutaLabel,
            asientosOcupados: asientosOcupados,
            capacidad: capacidad),
        const SizedBox(height: 16),
        if (forzado && enCamino) ...[
          _alertaAdmin(),
          const SizedBox(height: 16)
        ],
        if (!enCamino) ...[
          _botonArrancar(estaLleno: estaLleno,
              asientosOcupados: asientosOcupados,
              capacidad: capacidad,
              viaje: viaje),
          const SizedBox(height: 20),
        ],
        const Text('Asientos', style: TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _buildAsientosGrid(asientos, capacidad),
        const SizedBox(height: 8),
        Row(children: [
          _leyenda(const Color(0xFF10B981), 'Libre'),
          const SizedBox(width: 16),
          _leyenda(const Color(0xFF1E6BFF), 'Ocupado'),
          const SizedBox(width: 16),
          _leyenda(const Color(0xFFF59E0B), 'Bloqueado'),
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
                Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B),
                    size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                    'El boton se habilitara al llegar al destino final.',
                    style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12))),
              ]),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_cerrando ||
                  !llegoAlDestino ||
                  hayPasajerosPendientes)
                  ? null
                  : _terminarViaje,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                disabledBackgroundColor: const Color(0xFF374151),
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF6B7280),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: _cerrando
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Icon(
                !llegoAlDestino || hayPasajerosPendientes
                    ? Icons.lock_outline_rounded
                    : Icons.flag_rounded,
                size: 20,
              ),
              label: Text(
                _cerrando
                    ? 'Terminando...'
                    : !llegoAlDestino
                    ? 'Terminar viaje (en ruta...)'
                    : hayPasajerosPendientes
                    ? 'Esperando pasajeros'
                    : 'Terminar viaje',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _tabMapa({required bool enCamino, required Map<String,
      dynamic>? ubicacion, required String ruta}) {
    if (!enCamino) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.map_outlined, color: Color(0xFF6B7280), size: 48),
        const SizedBox(height: 12),
        const Text('El mapa estara disponible\ncuando arranques el viaje',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => _tabController.animateTo(0),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E6BFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0),
          child: const Text('Ir a Viaje'),
        ),
      ]));
    }

    final lat = (ubicacion?['lat'] as num?)?.toDouble() ??
        (ruta == 'chosica_lima' ? -11.9347 : -12.0950);
    final lng = (ubicacion?['lng'] as num?)?.toDouble() ??
        (ruta == 'chosica_lima' ? -76.6952 : -77.0450);
    final posActual = LatLng(lat, lng);
    final rutaPuntos = ruta == 'chosica_lima'
        ? _rutaChosicaLima
        : _rutaChosicaLima.reversed.toList();
    final origen = SimulationService.labelOrigen(ruta);
    final destino = SimulationService.labelDestino(ruta);

    return Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(target: posActual, zoom: 12),
        onMapCreated: (c) => _mapController = c,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        markers: {
          Marker(markerId: const MarkerId('conductor'), position: posActual,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'Colectivo')),
          Marker(markerId: const MarkerId('origen'), position: rutaPuntos.first,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(title: origen)),
          Marker(markerId: const MarkerId('destino'), position: rutaPuntos.last,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(title: destino)),
        },
        polylines: {
          Polyline(polylineId: const PolylineId('ruta'),
              points: rutaPuntos,
              color: const Color(0xFF1E6BFF),
              width: 4,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)]),
        },
      ),
      Positioned(
        bottom: 24, left: 16, right: 16,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF1E6BFF).withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4), blurRadius: 12)
            ],
          ),
          child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFF1E6BFF).withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: const Icon(
                    Icons.navigation_rounded, color: Color(0xFF1E6BFF),
                    size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ubicacion simulada', style: TextStyle(
                  color: Color(0xFF1E6BFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
              Text('Lat ${lat.toStringAsFixed(4)}  Lng ${lng.toStringAsFixed(
                  4)}',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                const Icon(Icons.radio_button_checked, color: Color(0xFF10B981),
                    size: 10),
                const SizedBox(width: 4),
                Text(origen, style: const TextStyle(color: Color(0xFF6B7280),
                    fontSize: 10)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(
                    Icons.flag_rounded, color: Color(0xFFFF3B30), size: 10),
                const SizedBox(width: 4),
                Text(destino, style: const TextStyle(color: Color(0xFF6B7280),
                    fontSize: 10)),
              ]),
            ]),
          ]),
        ),
      ),
    ]);
  }

  Widget _tabPasajeros({required List<Map<String,
      dynamic>> pasajeros, required int capacidad, required bool enCamino}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Pasajeros', style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFF1E6BFF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20)),
            child: Text('${pasajeros.length}/$capacidad',
                style: const TextStyle(color: Color(0xFF1E6BFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        if (pasajeros.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: enCamino
                  ? const Color(0xFF1E6BFF).withValues(alpha: 0.08)
                  : const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enCamino
                    ? const Color(0xFF1E6BFF).withValues(alpha: 0.25)
                    : const Color(0xFF10B981).withValues(alpha: 0.25),
              ),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded,
                  color: enCamino ? const Color(0xFF1E6BFF) : const Color(
                      0xFF10B981), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                enCamino
                    ? 'Toca Verificar en cada pasajero para validar su codigo al abordar.'
                    : 'El pasajero recibe su codigo al confirmar la reserva.',
                style: TextStyle(
                    color: enCamino ? const Color(0xFF1E6BFF) : const Color(
                        0xFF10B981), fontSize: 12),
              )),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        pasajeros.isEmpty
            ? _sinPasajeros()
            : Column(children: pasajeros.map((p) {
          final asientoNum = p['asiento'];
          final numero = asientoNum is int ? asientoNum : int.tryParse(
              asientoNum?.toString() ?? '0') ?? 0;
          return _pasajeroCard(pasajero: p,
              enCamino: enCamino,
              onValidar: () => _validarPasajero(p, numero));
        }).toList()),
      ]),
    );
  }

  Widget _bannerEstado(
      {required bool enCamino, required String rutaLabel, required int asientosOcupados, required int capacidad}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: enCamino
            ? const LinearGradient(
            colors: [Color(0xFF1E6BFF), Color(0xFF0A4BCC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight)
            : const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(enCamino ? Icons.directions_car_rounded : Icons
              .hourglass_top_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20)),
            child: Text(enCamino ? 'EN CAMINO' : 'ESPERANDO PASAJEROS',
                style: const TextStyle(color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ),
        ]),
        const SizedBox(height: 12),
        Text('$asientosOcupados de $capacidad asientos ocupados',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: capacidad > 0 ? asientosOcupados / capacidad : 0,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            )),
      ]),
    );
  }

  Widget _alertaAdmin() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: const Row(children: [
        Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFF59E0B),
            size: 20),
        SizedBox(width: 10),
        Expanded(
            child: Text('El administrador forzo el arranque de este viaje.',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13))),
      ]),
    );
  }

  Widget _botonArrancar(
      {required bool estaLleno, required int asientosOcupados, required int capacidad, required Map<
          String,
          dynamic> viaje}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: estaLleno
              ? const Color(0xFF10B981).withValues(alpha: 0.1)
              : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: estaLleno
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : const Color(0xFF1F2937)),
        ),
        child: Row(children: [
          Icon(estaLleno ? Icons.check_circle_rounded : Icons
              .hourglass_empty_rounded,
              color: estaLleno ? const Color(0xFF10B981) : const Color(
                  0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
            estaLleno
                ? 'Colectivo lleno! Puedes arrancar.'
                : 'Esperando: $asientosOcupados/$capacidad asientos',
            style: TextStyle(
                color: estaLleno ? const Color(0xFF10B981) : const Color(
                    0xFF9CA3AF),
                fontSize: 13, fontWeight: FontWeight.w500),
          )),
        ]),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _arrancando ? null : () => _arrancarColectivo(viaje),
          style: ElevatedButton.styleFrom(
            backgroundColor: estaLleno ? const Color(0xFF10B981) : const Color(
                0xFFF59E0B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          icon: _arrancando
              ? const SizedBox(width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.play_arrow_rounded, size: 26),
          label: Text(
            _arrancando ? 'Arrancando...' : estaLleno
                ? 'Arrancar — colectivo lleno'
                : 'Arrancar de todas formas',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ]);
  }


  Widget _sinPasajeros() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1F2937))),
      child: const Column(children: [
        Icon(Icons.people_outline, color: Color(0xFF6B7280), size: 40),
        SizedBox(height: 10),
        Text('Sin pasajeros aun',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
      ]),
    );
  }

  Widget _buildAsientosGrid(Map<String, dynamic> asientos, int capacidad) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: capacidad,
        itemBuilder: (context, index) {
          final key = 'asiento_${index + 1}';
          final asiento =
              (asientos[key] as Map?)?.cast<String, dynamic>() ?? {};

          final estado = asiento['estado'] ?? 'libre';

          Color color;
          IconData icon;

          if (estado == 'ocupado') {
            color = const Color(0xFFF59E0B); // amarillo
            icon = Icons.person;
          } else if (estado == 'abordado') {
            color = const Color(0xFF10B981); // verde
            icon = Icons.check_circle;
          } else if (estado == 'bloqueado') {
            color = const Color(0xFFFF3B30); // rojo
            icon = Icons.lock_outline;
          } else {
            color = const Color(0xFF6B7280); // gris
            icon = Icons.person_outline;
          }

          return Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 2),
                Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _pasajeroCard({required Map<String,
      dynamic> pasajero, required bool enCamino, required VoidCallback onValidar}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reservas')
          .where('viajeId', isEqualTo: widget.viajeId)
          .where('numeroAsiento', isEqualTo: pasajero['asiento'])
          .limit(1).snapshots(),
      builder: (context, snap) {
        final reservaData = snap.hasData && snap.data!.docs.isNotEmpty
            ? (snap.data!.docs.first.data() as Map<String, dynamic>)
            : null;
        final estadoReserva = reservaData?['estado'] ?? 'confirmada';
        final abordado = estadoReserva == 'abordado';
        final codigo = reservaData?['codigoVerificacion'] ?? '-----';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: abordado
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : const Color(0xFF1F2937)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: (abordado ? const Color(0xFF10B981) : const Color(
                          0xFF1E6BFF)).withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: Icon(
                      abordado ? Icons.how_to_reg_rounded : Icons.person,
                      color: abordado ? const Color(0xFF10B981) : const Color(
                          0xFF1E6BFF), size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pasajero['nombre'] ?? '-',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Asiento ${pasajero['asiento']} · ${pasajero['paradero'] ??
                    '-'}',
                    style: const TextStyle(color: Color(0xFF6B7280),
                        fontSize: 12)),
              ])),
              abordado
                  ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Abordado',
                      style: TextStyle(color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)))
                  : ElevatedButton(
                onPressed: enCamino ? onValidar : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6BFF),
                  disabledBackgroundColor: const Color(0xFF1F2937),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Verificar',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
            // Código visible solo si el viaje NO ha arrancado aún
            if (!enCamino && !abordado) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Row(children: [
                  const Icon(Icons.vpn_key_rounded, color: Color(0xFF6B7280),
                      size: 14),
                  const SizedBox(width: 8),
                  const Text('Codigo: ', style: TextStyle(color: Color(
                      0xFF6B7280), fontSize: 12)),
                  Text(codigo,
                      style: const TextStyle(
                          color: Color(0xFF1E6BFF), fontSize: 14,
                          fontWeight: FontWeight.w800, letterSpacing: 4)),
                ]),
              ),
            ],
          ]),
        );
      },
    );
  }
}

Widget _leyenda(Color color, String label) {
return Row(
children: [
Container(
width: 12,
height: 12,
decoration: BoxDecoration(
color: color,
shape: BoxShape.circle,
),
),
const SizedBox(width: 4),
Text(label),
],
);
}

Widget _leyendaCompleta() {
return Row(
children: [
_leyenda(const Color(0xFF6B7280), 'Libre'),
const SizedBox(width: 16),
_leyenda(const Color(0xFFF59E0B), 'Ocupado'),
const SizedBox(width: 16),
_leyenda(const Color(0xFF10B981), 'Abordado'),
const SizedBox(width: 16),
_leyenda(const Color(0xFFFF3B30), 'Bloqueado'),
],
);
}  // ← este cierre faltaba