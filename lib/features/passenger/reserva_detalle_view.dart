import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'cambiar_paradero_view.dart';
import 'conductor_public_perfil_view.dart';
import 'comprobante_pago_view.dart';
import 'paraderos_constants.dart';
import '../../app_theme.dart';

class _Punto {
  final double lat;
  final double lng;
  const _Punto(this.lat, this.lng);
}

class _Ruta {
  final List<_Punto> puntosInicio;
  final List<_Punto> puntosDestino;
  const _Ruta({required this.puntosInicio, required this.puntosDestino});
}

class ReservaDetalleView extends StatefulWidget {
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
  State<ReservaDetalleView> createState() => _ReservaDetalleViewState();
}

class _ReservaDetalleViewState extends State<ReservaDetalleView> {
  bool _confirmandoBajada = false;

  // Lógica de habilitación de botón "Ya bajé"
  StreamSubscription<Position>? _positionSubscription;
  Timer? _debounceTimer;
  Timer? _fallbackTimer;
  double? _distanciaAlObjetivo;
  bool _habilitarBotonBajada = false;
  String _etaText = '';
  String? _ultimaRutaEvaluada;
  
  // Seguimiento de movimiento para fallback
  DateTime _lastMovementTime = DateTime.now();
  Position? _lastPos;

  // Parámetros configurables
  static const double _radioHabilitacionMetros = 100.0;
  static const int _segundosConfirmacionSostenida = 20;
  static const double _velocidadPromedioKmh = 30.0;
  static const int _timeoutNoMovimientoMinutos = 2;
  static const double _umbralMovimientoMetros = 10.0;

  // Puntos de referencia individuales (constantes reales, no entradas de mapa).
  // Un acceso tipo mapa['clave']! NO es válido dentro de una expresión const,
  // por eso se definen como constantes propias y se reutilizan directamente.
  static const _Punto _puntoChosicaLima =
  _Punto(-12.164525647438607, -76.9851131814232);
  static const _Punto _puntoLimaChosica =
  _Punto(-12.193920, -76.971401);
  static const _Punto _puntoRuta3 =
  _Punto(-12.185074898652697, -76.96027054790292);
  static const _Punto _puntoRuta4 =
  _Punto(-12.1982351, -76.9969246);

  static const Map<String, _Punto> _puntosReferencia = {
    'chosica_lima': _puntoChosicaLima,
    'lima_chosica': _puntoLimaChosica,
    'ruta3': _puntoRuta3,
    'ruta4': _puntoRuta4,
  };

  static const Map<String, _Ruta> _rutas = {
    'chosica_lima': _Ruta(
      puntosInicio: [
        _puntoChosicaLima,
        _puntoRuta3,
        _puntoRuta4,
      ],
      puntosDestino: [
        _puntoLimaChosica,
      ],
    ),
    'lima_chosica': _Ruta(
      puntosInicio: [
        _puntoLimaChosica,
      ],
      puntosDestino: [
        _puntoChosicaLima,
        _puntoRuta3,
        _puntoRuta4,
      ],
    ),
  };

  @override
  void initState() {
    super.initState();
    _iniciarSeguimientoGps();
    _iniciarFallbackTimer();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _debounceTimer?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  void _iniciarFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_habilitarBotonBajada) return;
      
      final diff = DateTime.now().difference(_lastMovementTime);
      if (diff.inMinutes >= _timeoutNoMovimientoMinutos) {
        // Verificar si el viaje está en curso antes de activar
        _verificarYActivarSimulacion();
      }
    });
  }

  Future<void> _verificarYActivarSimulacion() async {
    final doc = await FirebaseFirestore.instance.collection('reservas').doc(widget.reservaId).get();
    if (doc.exists && doc.data()?['estado'] == 'abordado') {
      _activarLlegadaSimulada();
    }
  }

  Future<void> _activarLlegadaSimulada() async {
    if (_habilitarBotonBajada) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('reservas')
          .doc(widget.reservaId)
          .update({
            'llegadaSimulada': true,
            'habilitarBajada': true,
            'fechaSimulacion': FieldValue.serverTimestamp(),
          });
      
      setState(() {
        _habilitarBotonBajada = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Simulación de llegada activada por falta de movimiento GPS.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al activar llegada simulada: $e');
    }
  }

  void _iniciarSeguimientoGps() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Actualizar cada 5 metros
      ),
    ).listen((Position position) {
      // Actualizar tiempo de movimiento si la distancia es significativa
      if (_lastPos == null) {
        _lastPos = position;
        _lastMovementTime = DateTime.now();
      } else {
        final dist = Geolocator.distanceBetween(
          _lastPos!.latitude, _lastPos!.longitude, 
          position.latitude, position.longitude
        );
        if (dist >= _umbralMovimientoMetros) {
          _lastPos = position;
          _lastMovementTime = DateTime.now();
        }
      }

      if (_ultimaRutaEvaluada != null) {
        _evaluarProximidad(position, _ultimaRutaEvaluada!);
      }
    });
  }

  Future<void> _confirmarLlegadaPorGps() async {
    if (_habilitarBotonBajada) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('reservas')
          .doc(widget.reservaId)
          .update({
            'llegadaRealGps': true,
            'habilitarBajada': true,
            'fechaLlegadaGps': FieldValue.serverTimestamp(),
          });
      
      setState(() {
        _habilitarBotonBajada = true;
      });
    } catch (e) {
      debugPrint('Error al confirmar llegada por GPS: $e');
    }
  }

  void _evaluarProximidad(Position userPos, String rutaId) {
    final ruta = _rutas[rutaId];
    if (ruta == null) return;

    double distance = double.infinity;
    for (final punto in ruta.puntosDestino) {
      final d = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        punto.lat,
        punto.lng,
      );
      if (d < distance) {
        distance = d;
      }
    }

    setState(() {
      _distanciaAlObjetivo = distance;
      _etaText = _calcularETAText(distance);
    });

    // Lógica de proximidad sostenida (20 segundos)
    if (distance <= _radioHabilitacionMetros) {
      if (_debounceTimer == null && !_habilitarBotonBajada) {
        _debounceTimer = Timer(const Duration(seconds: _segundosConfirmacionSostenida), () {
          _confirmarLlegadaPorGps();
        });
      }
    } else {
      // Si sale del radio, reiniciamos el conteo y deshabilitamos
      _debounceTimer?.cancel();
      _debounceTimer = null;
      if (_habilitarBotonBajada) {
        setState(() => _habilitarBotonBajada = false);
      }
    }
  }

  String _calcularETAText(double distanceMeters) {
    if (distanceMeters <= _radioHabilitacionMetros) return "¡Has llegado!";

    // Tiempo = Distancia / Velocidad
    // Minutos = (Metros / 1000) / (Km/h / 60)
    final double speedMpm = (_velocidadPromedioKmh * 1000) / 60;
    final int minutes = (distanceMeters / speedMpm).ceil();

    return "ETA: $minutes min";
  }

  LatLng? _getParaderoCoords(String? nombre, String? ruta) {
    if (nombre == null || ruta == null) return null;
    final list = paraderosConCoordenadas[ruta];
    if (list == null) return null;
    try {
      return list.firstWhere((p) => p.nombre == nombre).coordinates;
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmarBajada() async {
    setState(() => _confirmandoBajada = true);
    try {
      await FirebaseFirestore.instance
          .collection('reservas')
          .doc(widget.reservaId)
          .update({'estado': 'finalizada'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Llegada confirmada! Gracias por viajar con SICOL.'), backgroundColor: CabifyColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: CabifyColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmandoBajada = false);
    }
  }

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
        stream: db.collection('reservas').doc(widget.reservaId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists) return const Center(child: Text('La reserva no existe.'));

          final res = snap.data!.data() as Map<String, dynamic>;
          final viajeId = res['viajeId'] ?? '';
          final monto = (res['monto'] as num?)?.toDouble() ?? 15.0;
          final estadoReserva = res['estado'] ?? 'confirmada';
          
          // Sincronizar flag de habilitación desde DB (fallback)
          if (res['habilitarBajada'] == true && !_habilitarBotonBajada) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _habilitarBotonBajada = true);
            });
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: viajeId.isNotEmpty ? db.collection('viajes').doc(viajeId).snapshots() : const Stream.empty(),
            builder: (context, viajeSnap) {
              final vData = viajeSnap.hasData && viajeSnap.data!.exists
                  ? (viajeSnap.data!.data() as Map<String, dynamic>)
                  : <String, dynamic>{};

              // Actualizamos la ruta para el seguimiento GPS del usuario
              final String? currentRuta = res['ruta'] ?? vData['ruta'];
              if (currentRuta != null && currentRuta != _ultimaRutaEvaluada) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() => _ultimaRutaEvaluada = currentRuta);
                });
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (estadoReserva == 'abordado') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: _habilitarBotonBajada
                              ? CabifyColors.success.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _habilitarBotonBajada ? CabifyColors.success : Colors.orange
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                                _habilitarBotonBajada ? Icons.check_circle : Icons.timer_outlined,
                                color: _habilitarBotonBajada ? CabifyColors.success : Colors.orange
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _habilitarBotonBajada
                                        ? '¡Has llegado a tu destino!'
                                        : 'En trayecto al paradero...',
                                    style: TextStyle(
                                        color: _habilitarBotonBajada ? CabifyColors.success : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13
                                    ),
                                  ),
                                  if (!_habilitarBotonBajada && _etaText.isNotEmpty)
                                    Text(
                                      _etaText,
                                      style: TextStyle(color: Colors.orange[800], fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (_habilitarBotonBajada && !_confirmandoBajada)
                              ? _confirmarBajada
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CabifyColors.success,
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: _confirmandoBajada
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                              _habilitarBotonBajada ? 'YA BAJÉ' : 'ESPERE A LLEGAR',
                              style: const TextStyle(fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

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
                          Text(widget.codigo, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 6)),
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
                            _buildDetail('Nombre', res['nombreViajero'] ?? widget.nombrePasajero),
                            const Divider(),
                            _buildDetail('Estado', estadoReserva.toString().toUpperCase()),
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
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ComprobantePagoView(reservaId: widget.reservaId)));
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
                    _buildCambiarParaderoButton(context, res, vData),
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
              final String rutaVal = res['ruta'] ?? viaje['ruta'] ?? '';
              final String viajeIdVal = res['viajeId'] ?? '';
              final String paraderoVal = res['paradero'] ?? '';
              final dynamic asientoRaw = res['numeroAsiento'];

              if (rutaVal.isEmpty || viajeIdVal.isEmpty || asientoRaw is! num) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No se pudo abrir el cambio de paradero: faltan datos de la reserva.'),
                    backgroundColor: CabifyColors.error,
                  ),
                );
                return;
              }

              Navigator.push(context, MaterialPageRoute(builder: (_) => CambiarParaderoView(
                reservaId: widget.reservaId,
                viajeId: viajeIdVal,
                currentParadero: paraderoVal,
                ruta: rutaVal,
                numeroAsiento: asientoRaw.toInt(),
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