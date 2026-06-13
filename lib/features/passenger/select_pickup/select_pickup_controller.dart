import 'package:flutter/material.dart';
import '../../../models/paradero_model.dart';
import '../../../services/paradero_service.dart';

/// CONTROLLER (MVC) — Separa la lógica del negocio de la vista.
/// La vista solo llama métodos de este controlador y observa el estado.
///
/// SRP (SOLID): esta clase tiene una única responsabilidad:
/// gestionar el estado de selección de punto de recojo y destino.
class SelectPickupController extends ChangeNotifier {
  final ParaderoService _service; // DAO inyectado — bajo acoplamiento (DIP)

  SelectPickupController({ParaderoService? service})
      : _service = service ?? ParaderoService();

  // ─── Estado ───────────────────────────────────────────────────────────────
  List<ParaderoModel> _paraderos = [];
  List<ParaderoModel> _sugerencias = [];

  ParaderoModel? _recojo;
  ParaderoModel? _destino;

  bool _cargando = true;
  String? _error;

  bool _gpsActivo = true; // EA01: simula estado del GPS

  // ─── Getters ─────────────────────────────────────────────────────────────
  List<ParaderoModel> get paraderos => _paraderos;
  List<ParaderoModel> get sugerencias => _sugerencias;
  ParaderoModel? get recojo => _recojo;
  ParaderoModel? get destino => _destino;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get gpsActivo => _gpsActivo;
  bool get seleccionCompleta => _recojo != null && _destino != null;

  // ─── Inicialización ───────────────────────────────────────────────────────
  Future<void> cargarParaderos() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    _paraderos = await _service.getParaderosActivos();
    _cargando = false;
    notifyListeners();
  }

  // ─── Selección directa (paraderos frecuentes) ─────────────────────────────
  void seleccionarRecojo(ParaderoModel p) {
    _recojo = p;
    // Si el destino es el mismo, lo limpiamos
    if (_destino?.id == p.id) _destino = null;
    notifyListeners();
  }

  void seleccionarDestino(ParaderoModel p) {
    _destino = p;
    notifyListeners();
  }

  // ─── Autocompletado ───────────────────────────────────────────────────────
  void filtrarSugerencias(String query) {
    _sugerencias = _service.filtrar(_paraderos, query);
    notifyListeners();
  }

  void limpiarSugerencias() {
    _sugerencias = [];
    notifyListeners();
  }

  // ─── GPS ──────────────────────────────────────────────────────────────────
  /// En producción aquí iría geolocator.getCurrentPosition().
  /// EA01: Si GPS desactivado el sistema solicita activarlo.
  Future<bool> capturarUbicacionGPS() async {
    // Simula chequeo de permisos
    if (!_gpsActivo) return false;
    // ubicación capturada como referencia interna (no se muestra al usuario)
    return true;
  }

  // Solo para testing / simulación
  void setGpsActivo(bool v) {
    _gpsActivo = v;
    notifyListeners();
  }

  // ─── Limpiar selección ────────────────────────────────────────────────────
  void limpiar() {
    _recojo = null;
    _destino = null;
    _sugerencias = [];
    notifyListeners();
  }
}
