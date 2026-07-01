import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/calificacion_service.dart';
import '../../app_theme.dart';

class CalificacionView extends StatefulWidget {
  final String viajeId;
  final String reservaId;
  final String conductorUid;
  final String conductorNombre;
  final String rutaLabel;

  const CalificacionView({
    super.key,
    required this.viajeId,
    required this.reservaId,
    required this.conductorUid,
    required this.conductorNombre,
    required this.rutaLabel,
  });

  @override
  State<CalificacionView> createState() => _CalificacionViewState();
}

class _CalificacionViewState extends State<CalificacionView> {
  final _service = CalificacionService();
  final _comentarioCtrl = TextEditingController();

  int _puntuacion = 0;
  bool _enviando = false;
  bool _yaCalificado = false;
  bool _verificando = true;

  @override
  void initState() {
    super.initState();
    _verificarCalificacion();
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarCalificacion() async {
    try {
      final pasajeroUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (pasajeroUid.isEmpty) {
        if (mounted) setState(() => _verificando = false);
        return;
      }
      final yaCalif = await _service.yaCalificado(
        viajeId: widget.viajeId,
        pasajeroUid: pasajeroUid,
      );
      if (mounted) {
        setState(() {
          _yaCalificado = yaCalif;
          _verificando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _enviarCalificacion() async {
    if (_puntuacion == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar('Selecciona al menos 1 estrella', isError: true),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      await _service.calificarViaje(
        viajeId: widget.viajeId,
        reservaId: widget.reservaId,
        conductorUid: widget.conductorUid,
        puntuacion: _puntuacion,
        comentario: _comentarioCtrl.text.trim().isEmpty ? null : _comentarioCtrl.text.trim(),
      );

      if (mounted) _mostrarExito();
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (msg.contains('Ya calificaste')) {
          setState(() => _yaCalificado = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(_snackBar(msg, isError: true));
        }
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.check_circle_rounded, color: CabifyColors.success, size: 80),
            const SizedBox(height: 24),
            Text('¡Gracias por calificar!', style: Theme.of(context).textTheme.displayLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Tu opinión ayuda a que ${widget.conductorNombre} siga mejorando su servicio.',
              style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('VOLVER A MIS VIAJES'),
            ),
          ],
        ),
      ),
    );
  }

  SnackBar _snackBar(String msg, {bool isError = false}) {
    return SnackBar(
      content: Text(msg),
      backgroundColor: isError ? CabifyColors.error : CabifyColors.success,
    );
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
        title: const Text('Calificar Viaje', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: _verificando
          ? const Center(child: CircularProgressIndicator(color: CabifyColors.primary))
          : _yaCalificado
              ? _buildYaCalificado()
              : _buildFormulario(),
    );
  }

  Widget _buildYaCalificado() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 80),
            const SizedBox(height: 24),
            Text('Viaje ya calificado', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 12),
            const Text(
              'Solo se permite una calificación por viaje. ¡Gracias por participar!',
              textAlign: TextAlign.center,
              style: TextStyle(color: CabifyColors.textSecondary),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('VOLVER'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFF3E8FF),
                    child: Icon(Icons.directions_bus_rounded, color: CabifyColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.rutaLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Conductor: ${widget.conductorNombre}', style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Text('¿Qué tal fue tu experiencia?', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Toca las estrellas para calificar', style: TextStyle(color: CabifyColors.textSecondary)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final estrella = i + 1;
                    final activo = estrella <= _puntuacion;
                    return IconButton(
                      onPressed: () => setState(() => _puntuacion = estrella),
                      icon: Icon(
                        activo ? Icons.star_rounded : Icons.star_border_rounded,
                        color: activo ? Colors.amber : const Color(0xFFD1D5DB),
                        size: 48,
                      ),
                    );
                  }),
                ),
                if (_puntuacion > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    ['Muy malo', 'Malo', 'Regular', 'Bueno', 'Excelente'][_puntuacion - 1],
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 48),
          const Text('COMENTARIO (OPCIONAL)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CabifyColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _comentarioCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Escribe algo sobre el viaje...',
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _enviando ? null : _enviarCalificacion,
            child: _enviando 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Text('ENVIAR CALIFICACIÓN'),
          ),
        ],
      ),
    );
  }
}
