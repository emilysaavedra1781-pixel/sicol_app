import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/trip_service.dart';
import '../../services/simulation_service.dart';
import '../../services/location_service.dart';
import 'tabs/trip_tab.dart';
import 'tabs/passengers_tab.dart';
import 'widgets/location_verification_map.dart';
import '../../app_theme.dart';
import 'dart:async';

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

class _DriverTripViewState extends State<DriverTripView> with SingleTickerProviderStateMixin {
  final _tripService = TripService();
  final _simService = SimulationService();
  final _locationService = LocationService();
  late TabController _tabController;

  bool _cerrando = false;
  bool _arrancando = false;
  
  // Lógica de fallback para timeout de GPS
  Timer? _fallbackTimer;
  DateTime _lastMovementTime = DateTime.now();
  Position? _lastPos;
  bool _fallbackActivo = false;
  static const int _timeoutNoMovimientoMinutos = 5; // Aumentado a 5 min para evitar falsos positivos
  static const double _umbralMovimientoMetros = 10.0;
  
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); 
    _iniciarSeguimientoGps();
    _iniciarFallbackTimer();
  }

  @override
  void dispose() {
    _simService.detenerSimulacion();
    _tabController.dispose();
    _positionSubscription?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  void _iniciarSeguimientoGps() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
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
    });
  }

  void _iniciarFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_fallbackActivo) return;
      
      final diff = DateTime.now().difference(_lastMovementTime);
      if (diff.inMinutes >= _timeoutNoMovimientoMinutos) {
        _activarFallbackTrip();
      }
    });
  }

  Future<void> _activarFallbackTrip() async {
    if (_fallbackActivo) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('viajes')
          .doc(widget.viajeId)
          .update({
            'llegadaSimulada': true,
            'fechaSimulacion': FieldValue.serverTimestamp(),
          });
      
      if (mounted) {
        setState(() => _fallbackActivo = true);
      }
    } catch (e) {
      debugPrint('Error al activar fallback de viaje: $e');
    }
  }

  bool _todosAbordaron(Map<String, dynamic> asientos) {
    final conPasajero = asientos.values.where((a) {
      final s = (a as Map?)?.cast<String, dynamic>() ?? {};
      return s['estado'] == 'ocupado' || s['estado'] == 'abordado';
    }).toList();
    if (conPasajero.isEmpty) return false;
    return conPasajero.every((a) => (a as Map).cast<String, dynamic>()['estado'] == 'abordado');
  }

  int _contarPendientes(Map<String, dynamic> asientos) {
    return asientos.values.where((a) {
      final s = (a as Map?)?.cast<String, dynamic>() ?? {};
      return s['estado'] == 'ocupado';
    }).length;
  }

  Future<void> _arrancarColectivo(Map<String, dynamic> viaje) async {
    final asientosOcupados = (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
    final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 4;
    final asientos = (viaje['asientos'] as Map?)?.cast<String, dynamic>() ?? {};
    final estaLleno = asientosOcupados >= capacidad;
    final pendientes = _contarPendientes(asientos);
    final forzado = viaje['forzadoPorAdmin'] == true;

    if (!forzado && (!estaLleno || pendientes > 0)) return;

    setState(() => _arrancando = true);
    try {
      await _tripService.arrancarColectivo(widget.viajeId);
      final ruta = viaje['ruta'] ?? 'chosica_lima';
      _simService.iniciarSimulacion(widget.viajeId, ruta);
      _tabController.animateTo(0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: CabifyColors.error));
      }
    } finally {
      if (mounted) setState(() => _arrancando = false);
    }
  }

  Future<void> _terminarViaje(String ruta) async {
    if (!_fallbackActivo) {
      VerificacionUbicacion verificacion;
      try {
        verificacion = await _locationService.verificarUbicacionParaFinalizarViaje(ruta);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: CabifyColors.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }

      // CP01: Verificar radio de 500m
      if (!verificacion.dentroDelRango) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Punto de destino'),
              content: const Text('No puedes cerrar el viaje aún. Debes estar en el punto de destino de la ruta para finalizar el servicio.'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ENTENDIDO'))],
            ),
          );
        }
        return;
      }
    }

    // CP02, CP03: Pantalla de resumen y advertencia de pasajeros
    if (!mounted) return;

    final tripDoc = await _tripService.getViajeStream(widget.viajeId).first;
    final tripData = tripDoc.data() as Map<String, dynamic>;
    final asientosOcupados = (tripData['asientosOcupados'] as num?)?.toInt() ?? 0;
    final todosBajaron = await _tripService.todosBajaron(widget.viajeId);

    if (!mounted) return;

    final continuar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resumen del Viaje', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resumenItem('Pasajeros atendidos', '$asientosOcupados'),
            _resumenItem('Monto recaudado', 'S/ ${(asientosOcupados * 10).toStringAsFixed(2)}'),
            if (_fallbackActivo)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('ℹ️ Finalización forzada por inactividad GPS.', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            if (!todosBajaron) ...[
              const SizedBox(height: 16),
              const Text('⚠️ Hay pasajeros que aún no han llegado a su destino. ¿Deseas cerrar el viaje de todas formas? Al confirmar, se marcarán como finalizados.',
                style: TextStyle(color: CabifyColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('VOLVER', style: TextStyle(color: CabifyColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.success, foregroundColor: Colors.white),
            child: const Text('CONFIRMAR CIERRE'),
          ),
        ],
      ),
    );

    if (continuar == true && mounted) {
      setState(() => _cerrando = true);
      try {
        _simService.detenerSimulacion();
        
        // Obtener coordenadas actuales para nuevo punto de disponibilidad
        final pos = await Geolocator.getCurrentPosition();
        await _tripService.cerrarViajeConDisponibilidad(
          viajeId: widget.viajeId,
          lat: pos.latitude,
          lng: pos.longitude,
        );
        
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          setState(() => _cerrando = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: CabifyColors.error));
        }
      }
    }
  }

  Widget _resumenItem(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 13)),
          Text(val, style: const TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _validarPasajero(Map<String, dynamic> pasajero, int numAsiento) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Validar Asiento $numAsiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pide el código al pasajero ${pasajero['nombre']}:'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: 'Código OTP'),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('VALIDAR')),
        ],
      ),
    );

    if (confirm == true) {
      final code = ctrl.text.trim().toUpperCase();
      // Obtener el código real desde Firestore
      final snap = await FirebaseFirestore.instance
          .collection('reservas')
          .where('viajeId', isEqualTo: widget.viajeId)
          .where('numeroAsiento', isEqualTo: numAsiento)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final realCode = snap.docs.first['codigoVerificacion'];
        if (code == realCode) {
          // Actualizar estado a abordado
          await _tripService.abordarPasajero(widget.viajeId, numAsiento, snap.docs.first.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Pasajero Validado!'), backgroundColor: CabifyColors.success));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código Incorrecto'), backgroundColor: CabifyColors.error));
          }
        }
      }
    }
  }

  Future<void> _validarGrupo(String codigoEncuentro) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Validar Grupo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa el Código de Encuentro dictado por el titular del grupo:'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: 'CÓDIGO (5 caracteres)'),
              textCapitalization: TextCapitalization.characters,
              maxLength: 5,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('VALIDAR GRUPO')),
        ],
      ),
    );

    if (confirm == true) {
      final code = ctrl.text.trim().toUpperCase();
      if (code != codigoEncuentro) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El código ingresado no coincide con este grupo.'), backgroundColor: CabifyColors.error)
          );
        }
        return;
      }

      try {
        await _tripService.abordarGrupo(widget.viajeId, code);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Grupo validado correctamente!'), backgroundColor: CabifyColors.success)
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: CabifyColors.error)
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _tripService.getViajeStream(widget.viajeId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text('Viaje no encontrado')));

        final viaje = snapshot.data!.data() as Map<String, dynamic>;
        final estado = viaje['estado'] ?? 'activo';
        final enCamino = estado == 'en_camino';
        final forzado = viaje['forzadoPorAdmin'] == true;
        final ruta = viaje['ruta'] ?? 'chosica_lima';
        final rutaLabel = viaje['rutaLabel'] ?? '';
        final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 4;
        final asientosOcupados = (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
        final asientos = (viaje['asientos'] as Map?)?.cast<String, dynamic>() ?? {};
        final todosAbordaron = _todosAbordaron(asientos);
        final pendientes = _contarPendientes(asientos);
        
        // Sincronizar flag de fallback desde Firestore
        if (viaje['llegadaSimulada'] == true && !_fallbackActivo) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _fallbackActivo = true);
          });
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reservas')
              .where('viajeId', isEqualTo: widget.viajeId)
              .where('estado', whereIn: ['confirmada', 'abordado'])
              .snapshots(),
          builder: (context, resSnap) {
            final bool todosBajaron = resSnap.hasData && resSnap.data!.docs.isEmpty;
            final llegoAlDestino = enCamino && (todosBajaron || _fallbackActivo);

            return Scaffold(
              appBar: AppBar(
                title: const Text('Viaje en curso'),
                bottom: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.dashboard_rounded), text: 'Resumen'),
                    Tab(icon: Icon(Icons.people_rounded), text: 'Pasajeros'),
                  ],
                ),
              ),
              body: TabBarView(
                controller: _tabController,
                children: [
                  TripTab(
                    viajeId: widget.viajeId,
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
                    onVerificar: () => _tabController.animateTo(1),
                    onTerminar: () => _terminarViaje(ruta),
                  ),
                  PassengersTab(
                    viajeId: widget.viajeId,
                    capacidad: capacidad,
                    enCamino: enCamino,
                    onValidar: (p, n) => _validarPasajero(p, n),
                    onValidarGrupo: (ce) => _validarGrupo(ce),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
