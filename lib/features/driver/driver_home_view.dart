import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../../services/trip_service.dart';
import '../../services/location_service.dart';
import '../../app_theme.dart';
import 'driver_trip_view.dart';
import 'driver_drawer.dart';

class DriverHomeView extends StatefulWidget {
  const DriverHomeView({super.key});

  @override
  State<DriverHomeView> createState() => _DriverHomeViewState();
}

class _DriverHomeViewState extends State<DriverHomeView> {
  final _authService = AuthService();
  final _tripService = TripService();
  final _locationService = LocationService();
  bool _poniendoDisponible = false;
  Position? _currentPosition;
  bool _gpsError = false;

  @override
  void initState() {
    super.initState();
    _checkInitialGps();
  }

  Future<void> _checkInitialGps() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _currentPosition = pos);
    } catch (e) {
      if (mounted) setState(() => _gpsError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Panel de Conductor', style: TextStyle(color: CabifyColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: CabifyColors.primary),
            onPressed: () => _authService.signOut(),
          )
        ],
      ),
      drawer: const DriverDrawer(currentRoute: '/home'),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          
          return StreamBuilder<QuerySnapshot>(
            stream: _tripService.getViajeActivoStream(),
            builder: (context, tripSnap) {
              final tieneViaje = tripSnap.hasData && tripSnap.data!.docs.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (userData['fotoUrl'] != null)
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: NetworkImage(userData['fotoUrl']),
                      )
                    else
                      const CircleAvatar(
                        radius: 60,
                        backgroundColor: Color(0xFFF3F4F6),
                        child: Icon(Icons.person, size: 60, color: CabifyColors.textSecondary),
                      ),
                    const SizedBox(height: 24),
                    Card(
                      color: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: CabifyColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Text('¡Hola, ${userData['nombre']}!', 
                              style: const TextStyle(color: CabifyColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(tieneViaje 
                              ? 'Tienes un viaje en curso. Debes cerrarlo antes de iniciar uno nuevo.' 
                              : '¿Listo para empezar a trabajar?', 
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: CabifyColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    if (userData['vehiculo']?['fotoVehiculoUrl'] != null) ...[
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(userData['vehiculo']['fotoVehiculoUrl'], height: 120, width: double.infinity, fit: BoxFit.cover),
                      ),
                    ],
                    const SizedBox(height: 48),
                    if (_currentPosition == null && !_gpsError)
                      const CircularProgressIndicator(color: CabifyColors.primary)
                    else if (_gpsError)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Column(
                          children: [
                            Icon(Icons.location_off_rounded, color: Colors.red, size: 32),
                            SizedBox(height: 8),
                            Text('No se puede obtener tu ubicación. Activa el GPS para continuar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else if (!tieneViaje)
                      ElevatedButton(
                        onPressed: _poniendoDisponible ? null : () => _iniciarDisponibilidad(userData),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CabifyColors.primary,
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: Text(_poniendoDisponible ? 'VERIFICANDO...' : 'INICIAR VIAJE'), // CP02
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => DriverTripView(
                            viajeId: tripSnap.data!.docs.first.id,
                            conductorData: userData,
                          )));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: const Text('IR A MI VIAJE ACTIVO'), // CP01, CP03
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _iniciarDisponibilidad(Map<String, dynamic> userData) async {
    setState(() => _poniendoDisponible = true);
    
    try {
      // CP05: Verificación GPS
      final verificacion = await _locationService.verificarUbicacionParaIniciarViaje();
      
      if (!mounted) return;

      if (!verificacion.dentroDelRango) {
        // CP02: Advertencia por ubicación incorrecta
        final bool? forzar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Ubicación incorrecta', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
            content: const Text('No estás en el punto de partida predeterminado. ¿Deseas iniciar el viaje desde tu ubicación actual?',
              style: TextStyle(color: CabifyColors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: CabifyColors.textSecondary))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.primary, foregroundColor: Colors.white),
                child: const Text('INICIAR DE TODAS FORMAS'),
              ),
            ],
          ),
        );

        if (forzar != true) {
          setState(() => _poniendoDisponible = false);
          return;
        }
      }

      // CP01: Registro viaje activo
      final viajeId = await _tripService.iniciarViaje(
        conductorData: userData,
        lat: _currentPosition?.latitude,
        lng: _currentPosition?.longitude,
        ruta: verificacion.dentroDelRango ? verificacion.rutaMasCercana : null,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje iniciado exitosamente'), backgroundColor: Color(0xFF10B981))
        );
        Navigator.push(context, MaterialPageRoute(builder: (_) => DriverTripView(
          viajeId: viajeId,
          conductorData: userData,
        )));
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _poniendoDisponible = false);
    }
  }
}
