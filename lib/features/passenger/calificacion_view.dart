import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/calificacion_service.dart';

class CalificacionView extends StatefulWidget {
  final String viajeId;
  final String conductorUid;
  final String conductorNombre;
  final String rutaLabel;

  const CalificacionView({
    super.key,
    required this.viajeId,
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

  int _puntuacion = 0; // 0 = sin seleccionar
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

  // CP03 — Verificar al entrar si ya fue calificado
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
      if (mounted) setState(() {
        _yaCalificado = yaCalif;
        _verificando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _enviarCalificacion() async {
    // CP04 — Puntuación mínima 1 estrella obligatoria
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
        conductorUid: widget.conductorUid,
        puntuacion: _puntuacion,
        comentario: _comentarioCtrl.text.trim().isEmpty
            ? null // CP02 — comentario opcional
            : _comentarioCtrl.text.trim(),
      );

      if (mounted) {
        _mostrarExito();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        // CP03 — Mensaje específico si ya calificó
        if (msg.contains('Ya calificaste')) {
          setState(() => _yaCalificado = true);
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(_snackBar(msg, isError: true));
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
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 64),
            const SizedBox(height: 16),
            const Text(
              '¡Gracias por tu calificación!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tu valoración ayuda a mejorar el servicio de ${widget.conductorNombre}.',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Mostrar estrellas seleccionadas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => Icon(
                i < _puntuacion ? Icons.star_rounded : Icons.star_border_rounded,
                color: const Color(0xFFF59E0B),
                size: 28,
              )),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Volver a mis reservas',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SnackBar _snackBar(String msg, {bool isError = false}) {
    return SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor:
      isError ? const Color(0xFFFF3B30) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF6B7280), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Calificar servicio',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: _verificando
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E6BFF)))
      // CP03 — Mostrar bloqueo si ya calificó
          : _yaCalificado
          ? _buildYaCalificado()
          : _buildFormulario(),
    );
  }

  // CP03 — Pantalla de bloqueo
  Widget _buildYaCalificado() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_rounded,
                  color: Color(0xFFF59E0B), size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ya calificaste este viaje',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Solo se permite una calificación por viaje.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E6BFF),
                  side: const BorderSide(color: Color(0xFF1E6BFF)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Volver',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Formulario principal
  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del viaje
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E6BFF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_bus_rounded,
                    color: Color(0xFF1E6BFF), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.rutaLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Conductor: ${widget.conductorNombre}',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: 32),

          // Selector de estrellas
          const Text(
            '¿Cómo fue tu viaje?',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toca las estrellas para calificar',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 20),

          // CP01, CP04, CP07 — Estrellas 1 a 5
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final estrella = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _puntuacion = estrella),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      estrella <= _puntuacion
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: estrella <= _puntuacion
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF374151),
                      size: estrella <= _puntuacion ? 52 : 44,
                    ),
                  ),
                );
              }),
            ),
          ),

          // Etiqueta de puntuación seleccionada
          const SizedBox(height: 12),
          Center(
            child: Text(
              _puntuacion == 0
                  ? 'Sin calificar'
                  : [
                '',
                'Muy malo',
                'Malo',
                'Regular',
                'Bueno',
                'Excelente',
              ][_puntuacion],
              style: TextStyle(
                color: _puntuacion == 0
                    ? const Color(0xFF4B5563)
                    : const Color(0xFFF59E0B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // CP02 — Comentario opcional
          Row(children: [
            const Text(
              'Comentario',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Opcional',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _comentarioCtrl,
            maxLines: 4,
            maxLength: 300,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Describe tu experiencia con el servicio...',
              hintStyle: const TextStyle(
                  color: Color(0xFF4B5563), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFF111827),
              counterStyle:
              const TextStyle(color: Color(0xFF4B5563), fontSize: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                const BorderSide(color: Color(0xFF1F2937)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                const BorderSide(color: Color(0xFF1F2937)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF1E6BFF), width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Botón enviar
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _enviando ? null : _enviarCalificacion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E6BFF),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                const Color(0xFF1E6BFF).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _enviando
                  ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                  : const Text(
                'Enviar calificación',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}