import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationVerificationMap extends StatefulWidget {
  final String title;
  final String subtitle;
  final LatLng targetLocation;
  final double radius;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const LocationVerificationMap({
    super.key,
    required this.title,
    required this.subtitle,
    required this.targetLocation,
    required this.radius,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<LocationVerificationMap> createState() => _LocationVerificationMapState();
}

class _LocationVerificationMapState extends State<LocationVerificationMap> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool withinRange = _currentPosition != null &&
        Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              widget.targetLocation.latitude,
              widget.targetLocation.longitude,
            ) <=
            widget.radius;

    return Container(
      color: const Color(0xFF111827), // Fondo oscuro
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B21F5)))
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentPosition ?? widget.targetLocation,
                        zoom: 15,
                      ),
                      onMapCreated: (c) => _mapController = c,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: false,
                      circles: {
                        Circle(
                          circleId: const CircleId('range'),
                          center: widget.targetLocation,
                          radius: widget.radius,
                          fillColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                          strokeColor: const Color(0xFF10B981),
                          strokeWidth: 2,
                        ),
                      },
                      markers: {
                        Marker(
                          markerId: const MarkerId('target'),
                          position: widget.targetLocation,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed),
                          infoWindow: const InfoWindow(title: 'Punto de control'),
                        ),
                      },
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.white70)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: withinRange
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(withinRange ? 'Confirmar' : 'Iniciar de todas formas'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
