import 'package:flutter/material.dart';
import '../../services/incidencia_service.dart';
import '../../app_theme.dart';

class ReportarIncidenciaView extends StatefulWidget {
  final String rolUsuario; 
  final String? viajeId;

  const ReportarIncidenciaView({
    super.key,
    required this.rolUsuario,
    this.viajeId,
  });

  @override
  State<ReportarIncidenciaView> createState() => _ReportarIncidenciaViewState();
}

class _ReportarIncidenciaViewState extends State<ReportarIncidenciaView> {
  final _incidenciaService = IncidenciaService();
  final _descripcionCtrl = TextEditingController();

  String? _tipoSeleccionado;
  int _minutosRetraso = 5; // Valor por defecto
  bool _enviando = false;

  static const List<String> _tiposConductor = [
    'Retraso',
    'Accidente',
    'Desvío de ruta',
    'Problema con pasajero',
    'Otro',
  ];

  static const List<String> _tiposPasajero = [
    'Conductor no se presentó',
    'Vehículo en mal estado',
    'Comportamiento inapropiado',
    'Otro',
  ];

  List<String> get _tipos => widget.rolUsuario == 'conductor' ? _tiposConductor : _tiposPasajero;

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_tipoSeleccionado == null || _descripcionCtrl.text.isEmpty) return;
    setState(() => _enviando = true);
    try {
      // Si el rol es pasajero y no hay viajeId, le ponemos 'GENERAL' para que no falle el service
      final finalViajeId = (widget.rolUsuario == 'pasajero' && (widget.viajeId == null || widget.viajeId!.isEmpty))
          ? 'REPORTE_GENERAL'
          : widget.viajeId;

      await _incidenciaService.crearIncidencia(
        rolUsuario: widget.rolUsuario,
        tipo: _tipoSeleccionado!,
        descripcion: _descripcionCtrl.text,
        viajeId: finalViajeId,
        minutosRetraso: _tipoSeleccionado == 'Retraso' ? _minutosRetraso : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte enviado correctamente'), backgroundColor: CabifyColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: CabifyColors.error));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CabifyColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Reportar Incidencia', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Qué ocurrió?', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 8),
            const Text('Cuéntanos los detalles del incidente para ayudarte.', style: TextStyle(color: CabifyColors.textSecondary)),
            const SizedBox(height: 32),
            DropdownButtonFormField<String>(
              initialValue: _tipoSeleccionado,
              hint: const Text('Selecciona el tipo de problema'),
              items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _tipoSeleccionado = v),
            ),
            if (_tipoSeleccionado == 'Retraso' && widget.rolUsuario == 'conductor') ...[
              const SizedBox(height: 24),
              const Text('¿Cuántos minutos de retraso aproximadamente?', 
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CabifyColors.textSecondary)),
              Slider(
                value: _minutosRetraso.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                label: '$_minutosRetraso min',
                onChanged: (v) => setState(() => _minutosRetraso = v.toInt()),
              ),
              Center(child: Text('$_minutosRetraso minutos', style: const TextStyle(fontWeight: FontWeight.w900, color: CabifyColors.primary))),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _descripcionCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Describe lo que pasó con el mayor detalle posible...',
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _enviando ? null : _enviar,
              child: _enviando 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text('ENVIAR REPORTE'),
            ),
          ],
        ),
      ),
    );
  }
}
