import 'package:flutter/material.dart';
import '../../services/incidencia_service.dart';

class ReportarIncidenciaView extends StatefulWidget {
  final String rolUsuario; // 'conductor' | 'pasajero'

  /// Para pasajero: obligatorio (viaje con reserva confirmada).
  /// Para conductor: opcional.
  final String? viajeId;

  const ReportarIncidenciaView({
    super.key,
    required this.rolUsuario,
    this.viajeId,
  }) : assert(
  rolUsuario == 'conductor' || viajeId != null,
  'El pasajero debe tener un viajeId (reserva confirmada).',
  );

  @override
  State<ReportarIncidenciaView> createState() =>
      _ReportarIncidenciaViewState();
}

class _ReportarIncidenciaViewState extends State<ReportarIncidenciaView> {
  final _incidenciaService = IncidenciaService();
  final _descripcionCtrl = TextEditingController();

  String? _tipoSeleccionado;
  bool _enviando = false;

  static const List<String> _tiposConductor = [
    'Pasajero no se presentó',
    'Problema con el pago',
    'Comportamiento inapropiado del pasajero',
    'Problema con la ruta',
    'Otro',
  ];

  static const List<String> _tiposPasajero = [
    'Conductor no se presentó',
    'Retraso significativo',
    'Comportamiento inapropiado del conductor',
    'Problema con el vehículo',
    'Cobro incorrecto',
    'Otro',
  ];

  List<String> get _tipos =>
      widget.rolUsuario == 'conductor' ? _tiposConductor : _tiposPasajero;

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_tipoSeleccionado == null) {
      _mostrarError('Selecciona un tipo de incidencia.');
      return;
    }
    if (_descripcionCtrl.text.trim().isEmpty) {
      _mostrarError('Describe brevemente lo que ocurrió.');
      return;
    }

    setState(() => _enviando = true);
    try {
      await _incidenciaService.crearIncidencia(
        rolUsuario: widget.rolUsuario,
        tipo: _tipoSeleccionado!,
        descripcion: _descripcionCtrl.text,
        viajeId: widget.viajeId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incidencia registrada correctamente.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      _mostrarError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('Reportar incidencia',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo de incidencia',
                style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ..._tipos.map((tipo) => _opcionTipo(tipo)),
            const SizedBox(height: 20),
            const Text('Descripción',
                style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: TextField(
                controller: _descripcionCtrl,
                maxLines: 5,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Cuéntanos qué ocurrió...',
                  hintStyle: TextStyle(color: Color(0xFF6B7280)),
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _enviando
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                    : const Text('Enviar reporte',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcionTipo(String tipo) {
    final seleccionado = _tipoSeleccionado == tipo;
    return GestureDetector(
      onTap: () => setState(() => _tipoSeleccionado = tipo),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: seleccionado
              ? const Color(0xFF1E6BFF).withValues(alpha: 0.1)
              : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado
                ? const Color(0xFF1E6BFF)
                : const Color(0xFF1F2937),
          ),
        ),
        child: Row(
          children: [
            Icon(
              seleccionado
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: seleccionado
                  ? const Color(0xFF1E6BFF)
                  : const Color(0xFF6B7280),
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(tipo,
                style: TextStyle(
                    color: seleccionado ? Colors.white : const Color(0xFFD1D5DB),
                    fontSize: 13,
                    fontWeight:
                    seleccionado ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}