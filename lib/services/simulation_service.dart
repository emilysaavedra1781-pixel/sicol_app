import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Coordenadas reales de la ruta Chosica → Lima (Av. Petit Thouars)
/// Plaza de Armas de Chosica → Av. Petit Thouars, San Isidro
class SimulationService {
  final _db = FirebaseFirestore.instance;
  Timer? _timer;

  bool get estaDetenido => _timer == null;

  // ── Puntos de la ruta Chosica → Lima ──────────────────────────────────────
  // Ruta real por Carretera Central → Javier Prado → Petit Thouars
  static const List<Map<String, double>> _puntosChosicaLima = [
    {'lat': -11.9347, 'lng': -76.6952}, // Plaza de Armas de Chosica
    {'lat': -11.9280, 'lng': -76.6750}, // Chosica salida
    {'lat': -11.9100, 'lng': -76.6300}, // Ñaña
    {'lat': -11.8900, 'lng': -76.5800}, // Huachipa
    {'lat': -11.9050, 'lng': -76.9900}, // Ate Vitarte zona industrial
    {'lat': -12.0200, 'lng': -76.9500}, // Santa Anita
    {'lat': -12.0400, 'lng': -76.9800}, // La Molina inicio
    {'lat': -12.0650, 'lng': -77.0000}, // Javier Prado Este
    {'lat': -12.0850, 'lng': -77.0200}, // Javier Prado cruce
    {'lat': -12.0900, 'lng': -77.0350}, // San Isidro inicio
    {'lat': -12.0950, 'lng': -77.0450}, // Av. Petit Thouars, San Isidro
  ];

  // ── Puntos de la ruta Lima → Chosica (inverso) ───────────────────────────
  static List<Map<String, double>> get _puntosLimaChosica =>
      _puntosChosicaLima.reversed.toList();

  /// Inicia simulación de movimiento para un viaje.
  /// Actualiza lat/lng en Firestore cada 4 segundos avanzando por la ruta.
  void iniciarSimulacion(String viajeId, String ruta) {
    _timer?.cancel();
    final puntos =
    ruta == 'chosica_lima' ? _puntosChosicaLima : _puntosLimaChosica;
    int indice = 0;

    // Escribir posición inicial inmediatamente
    _actualizarUbicacion(viajeId, puntos[0]);

    _timer = Timer.periodic(const Duration(seconds: 4), (t) async {
      indice++;
      if (indice >= puntos.length) {
        indice = puntos.length - 1;
        t.cancel();
        return;
      }
      await _actualizarUbicacion(viajeId, puntos[indice]);
    });
  }

  void detenerSimulacion() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _actualizarUbicacion(
      String viajeId, Map<String, double> punto) async {
    try {
      await _db.collection('viajes').doc(viajeId).update({
        'ubicacionActual': {
          'lat': punto['lat'],
          'lng': punto['lng'],
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
    } catch (_) {}
  }

  /// Retorna la coordenada de inicio según ruta (para mostrar en mapa estático)
  static Map<String, double> coordenadaInicio(String ruta) {
    return ruta == 'chosica_lima'
        ? _puntosChosicaLima.first
        : _puntosLimaChosica.first;
  }

  /// Retorna la coordenada de destino según ruta
  static Map<String, double> coordenadaFin(String ruta) {
    return ruta == 'chosica_lima'
        ? _puntosChosicaLima.last
        : _puntosLimaChosica.last;
  }

  /// Label del punto de origen
  static String labelOrigen(String ruta) {
    return ruta == 'chosica_lima'
        ? 'Plaza de Armas de Chosica'
        : 'Av. Petit Thouars, San Isidro';
  }

  /// Label del destino
  static String labelDestino(String ruta) {
    return ruta == 'chosica_lima'
        ? 'Av. Petit Thouars, San Isidro'
        : 'Plaza de Armas de Chosica';
  }
}
