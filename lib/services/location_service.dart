import 'package:geolocator/geolocator.dart';

/// Resultado de la verificación de ubicación.
class VerificacionUbicacion {
  final bool dentroDelRango;
  final double distanciaMetros;
  final String rutaMasCercana;

  VerificacionUbicacion({
    required this.dentroDelRango,
    required this.distanciaMetros,
    required this.rutaMasCercana,
  });
}

class LocationService {
  static const double _radioPermitidoMetros = 200;

  // 🔧 TODO: reemplaza estas coordenadas con las reales de cada ruta.
  // Por ahora son aproximadas (Plaza de Armas Chosica / Plaza San Martín Lima).
  // Para probar: cambia temporalmente una de las dos por tu ubicación actual
  // (Google Maps → mantén presionado tu pin → copia lat, lng).
  static const Map<String, _Punto> _puntosInicioRuta = {
    'chosica_lima': _Punto(-12.164316147650368, -76.98500568841465), // 🔧 TU ubicación, temporal
    'lima_chosica': _Punto(-12.164316147650368, -76.98500568841465), // 🔧 TU ubicación, temporal (misma)
  };

  /// Pide permisos de ubicación si no los tiene.
  Future<bool> _asegurarPermisos() async {
    LocationPermission permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      return false;
    }

    final servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) return false;

    return true;
  }

  /// Verifica que la ubicación actual del conductor esté dentro del radio
  /// permitido de alguno de los puntos de inicio de ruta.
  /// Lanza una excepción con mensaje claro si algo falla.
  Future<VerificacionUbicacion> verificarUbicacionParaIniciarViaje() async {
    final tienePermiso = await _asegurarPermisos();
    if (!tienePermiso) {
      throw Exception(
          'Necesitas activar el permiso de ubicación para iniciar un viaje.');
    }

    final posicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    String rutaMasCercana = '-';
    double distanciaMinima = double.infinity;

    for (final entry in _puntosInicioRuta.entries) {
      final distancia = Geolocator.distanceBetween(
        posicion.latitude,
        posicion.longitude,
        entry.value.lat,
        entry.value.lng,
      );
      if (distancia < distanciaMinima) {
        distanciaMinima = distancia;
        rutaMasCercana = entry.key;
      }
    }

    return VerificacionUbicacion(
      dentroDelRango: distanciaMinima <= _radioPermitidoMetros,
      distanciaMetros: distanciaMinima,
      rutaMasCercana: rutaMasCercana,
    );
  }

  /// Verifica que la ubicación actual del conductor esté dentro del radio
  /// permitido del punto de DESTINO de la ruta dada, antes de finalizar el viaje.
  Future<VerificacionUbicacion> verificarUbicacionParaFinalizarViaje(
      String rutaActual) async {
    final tienePermiso = await _asegurarPermisos();
    if (!tienePermiso) {
      throw Exception(
          'Necesitas activar el permiso de ubicación para finalizar el viaje.');
    }

    // El destino es el punto de inicio de la ruta contraria.
    final rutaDestino =
    rutaActual == 'chosica_lima' ? 'lima_chosica' : 'chosica_lima';
    final puntoDestino = _puntosInicioRuta[rutaDestino];

    if (puntoDestino == null) {
      throw Exception('No se reconoce la ruta del viaje.');
    }

    final posicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final distancia = Geolocator.distanceBetween(
      posicion.latitude,
      posicion.longitude,
      puntoDestino.lat,
      puntoDestino.lng,
    );

    return VerificacionUbicacion(
      dentroDelRango: distancia <= _radioPermitidoMetros,
      distanciaMetros: distancia,
      rutaMasCercana: rutaDestino,
    );
  }
}

class _Punto {
  final double lat;
  final double lng;
  const _Punto(this.lat, this.lng);
}