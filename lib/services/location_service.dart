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

class LocationService {
  static const double _radioPermitidoMetros = 500; // RF34: Radio de 500 metros
  static const double _radioCierreMetros = 500;

  // Puntos de referencia individuales (constantes reales, no entradas de mapa).
  // Esto es lo que permite reutilizarlos como const más abajo.
  static const _Punto _puntoChosicaLima =
  _Punto(-12.164525647438607, -76.9851131814232);
  static const _Punto _puntoLimaChosica =
  _Punto(-12.193920, -76.971401);
  static const _Punto _puntoRuta3 =
  _Punto(-12.185074898652697, -76.96027054790292);
  static const _Punto _puntoRuta4 =
  _Punto(-12.1982351, -76.9969246);

  // Se conserva por si algo del proyecto todavía necesita consultar
  // los 4 puntos de referencia por nombre.
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
  /// permitido de alguno de los puntos de inicio de las rutas principales.
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

    for (final entry in _rutas.entries) {
      for (final punto in entry.value.puntosInicio) {
        final distancia = Geolocator.distanceBetween(
          posicion.latitude,
          posicion.longitude,
          punto.lat,
          punto.lng,
        );
        if (distancia < distanciaMinima) {
          distanciaMinima = distancia;
          rutaMasCercana = entry.key;
        }
      }
    }

    return VerificacionUbicacion(
      dentroDelRango: distanciaMinima <= _radioPermitidoMetros,
      distanciaMetros: distanciaMinima,
      rutaMasCercana: rutaMasCercana,
    );
  }

  /// Verifica que la ubicación actual del conductor esté dentro del radio
  /// permitido de alguno de los puntos de DESTINO de la ruta dada.
  Future<VerificacionUbicacion> verificarUbicacionParaFinalizarViaje(
      String rutaActual) async {
    final tienePermiso = await _asegurarPermisos();
    if (!tienePermiso) {
      throw Exception(
          'Necesitas activar el permiso de ubicación para finalizar el viaje.');
    }

    final ruta = _rutas[rutaActual];
    if (ruta == null) {
      throw Exception('No se reconoce la ruta del viaje.');
    }

    final posicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    double distanciaMinima = double.infinity;
    for (final punto in ruta.puntosDestino) {
      final distancia = Geolocator.distanceBetween(
        posicion.latitude,
        posicion.longitude,
        punto.lat,
        punto.lng,
      );
      if (distancia < distanciaMinima) {
        distanciaMinima = distancia;
      }
    }

    return VerificacionUbicacion(
      dentroDelRango: distanciaMinima <= _radioCierreMetros,
      distanciaMetros: distanciaMinima,
      rutaMasCercana: rutaActual,
    );
  }

  List<Map<String, double>> getCoordenadasInicio(String rutaId) {
    final ruta = _rutas[rutaId];
    if (ruta == null) return [];
    return ruta.puntosInicio.map((p) => {'lat': p.lat, 'lng': p.lng}).toList();
  }

  List<Map<String, double>> getCoordenadasDestino(String rutaId) {
    final ruta = _rutas[rutaId];
    if (ruta == null) return [];
    return ruta.puntosDestino.map((p) => {'lat': p.lat, 'lng': p.lng}).toList();
  }

  double getRadioPermitido() => _radioPermitidoMetros;
}