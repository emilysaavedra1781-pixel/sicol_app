import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/booking_service.dart';

class SeatSelectionView extends StatefulWidget {
  final String viajeId;
  final Map<String, dynamic> viajeData;

  const SeatSelectionView({
    super.key,
    required this.viajeId,
    required this.viajeData,
  });

  @override
  State<SeatSelectionView> createState() => _SeatSelectionViewState();
}

class _SeatSelectionViewState extends State<SeatSelectionView> {
  final _bookingService = BookingService();
  int? _asientoSeleccionado;
  final _nombreCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _paraderoCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dniCtrl.dispose();
    _paraderoCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmarReserva() async {
    if (_asientoSeleccionado == null) {
      setState(() => _error = 'Selecciona un asiento.');
      return;
    }
    if (_nombreCtrl.text.trim().isEmpty ||
        _dniCtrl.text.trim().isEmpty ||
        _paraderoCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Completa todos los campos.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar pago',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payment_rounded,
                color: Color(0xFF1E6BFF), size: 48),
            const SizedBox(height: 16),
            _resumenRow('Viajero', _nombreCtrl.text.trim()),
            _resumenRow('DNI', _dniCtrl.text.trim()),
            _resumenRow('Paradero', _paraderoCtrl.text.trim()),
            _resumenRow('Asiento', '$_asientoSeleccionado'),
            _resumenRow('Ruta', widget.viajeData['rutaLabel'] ?? ''),
            const Divider(color: Color(0xFF1F2937), height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total a pagar',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                Text('S/ 15.00',
                    style: TextStyle(
                        color: Color(0xFF1E6BFF),
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Pago simulado — modo desarrollo',
                        style:
                        TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E6BFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Pagar S/ 15.00',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _bookingService.reservarAsiento(
        viajeId: widget.viajeId,
        numeroAsiento: _asientoSeleccionado!,
        nombreViajero: _nombreCtrl.text.trim(),
        dniViajero: _dniCtrl.text.trim(),
        paradero: _paraderoCtrl.text.trim(),
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF10B981), size: 40),
              ),
              const SizedBox(height: 16),
              const Text('¡Reserva confirmada!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Asiento $_asientoSeleccionado reservado en ${widget.viajeData['rutaLabel']}',
                textAlign: TextAlign.center,
                style:
                const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 24),
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
                  ),
                  child: const Text('Aceptar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Widget _resumenRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
              const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asientos =
        (widget.viajeData['asientos'] as Map?)?.cast<String, dynamic>() ?? {};
    final capacidad =
        (widget.viajeData['capacidad'] as num?)?.toInt() ?? 4;

    // Cast seguro del mapa vehiculo
    final vehiculo =
        (widget.viajeData['vehiculo'] as Map?)?.cast<String, dynamic>() ?? {};
    final placa = vehiculo['placa'] ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Seleccionar asiento',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info del viaje
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_rounded,
                      color: Color(0xFF1E6BFF), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.viajeData['rutaLabel'] ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Placa: $placa • S/ 15.00',
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Gráfico asientos
            const Text('Elige tu asiento',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: capacidad,
                itemBuilder: (context, index) {
                  final num = index + 1;
                  final key = 'asiento_$num';
                  final asiento =
                      (asientos[key] as Map?)?.cast<String, dynamic>() ?? {};
                  final estado = asiento['estado'] ?? 'libre';
                  final seleccionado = _asientoSeleccionado == num;

                  Color bgColor;
                  Color borderColor;
                  Color textColor;
                  IconData icon;
                  bool tappable = false;

                  if (seleccionado) {
                    bgColor =
                        const Color(0xFF1E6BFF).withValues(alpha: 0.3);
                    borderColor = const Color(0xFF1E6BFF);
                    textColor = Colors.white;
                    icon = Icons.person;
                    tappable = true;
                  } else if (estado == 'libre') {
                    bgColor =
                        const Color(0xFF10B981).withValues(alpha: 0.1);
                    borderColor =
                        const Color(0xFF10B981).withValues(alpha: 0.4);
                    textColor = const Color(0xFF10B981);
                    icon = Icons.person_outline;
                    tappable = true;
                  } else if (estado == 'ocupado') {
                    bgColor = const Color(0xFF1F2937);
                    borderColor = const Color(0xFF374151);
                    textColor = const Color(0xFF4B5563);
                    icon = Icons.person;
                    tappable = false;
                  } else {
                    bgColor =
                        const Color(0xFFF59E0B).withValues(alpha: 0.1);
                    borderColor =
                        const Color(0xFFF59E0B).withValues(alpha: 0.4);
                    textColor = const Color(0xFFF59E0B);
                    icon = Icons.lock_outline;
                    tappable = false;
                  }

                  return GestureDetector(
                    onTap: tappable
                        ? () =>
                        setState(() => _asientoSeleccionado = num)
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: borderColor,
                            width: seleccionado ? 2 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: textColor, size: 20),
                          const SizedBox(height: 2),
                          Text('$num',
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Leyenda
            Row(
              children: [
                _leyenda(const Color(0xFF10B981), 'Libre'),
                const SizedBox(width: 16),
                _leyenda(const Color(0xFF1E6BFF), 'Seleccionado'),
                const SizedBox(width: 16),
                _leyenda(const Color(0xFF4B5563), 'Ocupado'),
              ],
            ),
            const SizedBox(height: 24),

            // Datos del viajero (RF50)
            const Text('Datos del viajero',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFFF3B30), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFFFF3B30), fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            _buildField(
              controller: _nombreCtrl,
              hint: 'Nombre completo del viajero',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _dniCtrl,
              hint: 'DNI del viajero',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _paraderoCtrl,
              hint: 'Paradero de recojo',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _confirmarReserva,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                    : const Text('Confirmar y pagar S/ 15.00',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _leyenda(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF4B5563)),
        prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 20),
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1F2937)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1F2937)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFF1E6BFF), width: 1.5),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}