import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reserva_detalle_view.dart';

// Mapa de labels por ruta
const Map<String, String> _rutaLabels = {
  'chosica_lima': 'Chosica → Lima (Carretera Central)',
  'lima_chosica': 'Lima → Chosica (Carretera Central)',
};

class SeatSelectionView extends StatefulWidget {
  final String viajeId;
  final String? nombrePasajero;
  final String? dniPasajero;
  final String paradero;
  final String? rutaSeleccionada;

  const SeatSelectionView({
    super.key,
    required this.viajeId,
    required this.paradero,
    this.nombrePasajero,
    this.dniPasajero,
    this.rutaSeleccionada,
  });

  @override
  State<SeatSelectionView> createState() => _SeatSelectionViewState();
}

class _SeatSelectionViewState extends State<SeatSelectionView> {
  int? _asientoSeleccionado;
  final _db = FirebaseFirestore.instance;
  bool _guardando = false;

  // ── NUEVO: nombre del acompañante (si se agrega uno) ──────────────────────
  String? _nombreAcompanante;
  final _nombreAcompananteCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreAcompananteCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  String _generarCodigoOTP() {
    const caracteres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
        5, (_) => caracteres[random.nextInt(caracteres.length)]).join();
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _confirmarReserva(Map<String, dynamic> viajeData) async {
    if (_asientoSeleccionado == null || _guardando) return;

    setState(() => _guardando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final codigoUnico = _generarCodigoOTP();
      final numeroAsiento = _asientoSeleccionado!;
      final key = 'asiento_$numeroAsiento';

      // ── NUEVO: usa nombre del acompañante si existe, si no el del pasajero ──
      final nombreFinal =
          _nombreAcompanante ?? widget.nombrePasajero ?? 'Pasajero';

      final reservaRef = _db.collection('reservas').doc();
      final reservaId = reservaRef.id;

      await _db.runTransaction((transaction) async {
        final viajeRef = _db.collection('viajes').doc(widget.viajeId);
        final viajeSnap = await transaction.get(viajeRef);

        if (!viajeSnap.exists) {
          throw Exception('El viaje ya no está disponible.');
        }

        final data = viajeSnap.data()!;

        // ── Verificar asiento libre ──────────────────────────────────
        final ocupadosLista =
        List<int>.from(data['asientosListaOcupados'] ?? []);
        if (ocupadosLista.contains(numeroAsiento)) {
          throw Exception(
              '¡El asiento $numeroAsiento acaba de ser ocupado!');
        }

        final asientosMapa =
        Map<String, dynamic>.from(data['asientos'] ?? {});
        final asientoActual =
        (asientosMapa[key] as Map?)?.cast<String, dynamic>();
        if (asientoActual != null && asientoActual['estado'] != 'libre') {
          throw Exception(
              '¡El asiento $numeroAsiento ya no está disponible!');
        }

        // ── Actualizar asientos ──────────────────────────────────────
        ocupadosLista.add(numeroAsiento);
        asientosMapa[key] = {
          'numero': numeroAsiento,
          'estado': 'ocupado',
          'pasajero': {
            'uid': user?.uid ?? '',
            'nombre': nombreFinal,           // ← usa nombreFinal
            'dni': widget.dniPasajero ?? '',
            'paradero': widget.paradero,
            'asiento': numeroAsiento,
          },
        };

        final rutaActual = data['ruta'];
        final rutaFinal = rutaActual ?? widget.rutaSeleccionada;
        final rutaLabelFinal = rutaActual != null
            ? data['rutaLabel']
            : _rutaLabels[widget.rutaSeleccionada] ??
            widget.rutaSeleccionada;


        transaction.update(viajeRef, {
          'asientosListaOcupados': ocupadosLista,
          'asientos': asientosMapa,
          'asientosOcupados': ocupadosLista.length,
          'ingresoTotal': FieldValue.increment(15),
          if (rutaActual == null) 'ruta': rutaFinal,
          if (rutaActual == null) 'rutaLabel': rutaLabelFinal,
        });

        // ── Crear reserva ────────────────────────────────────────────

        transaction.set(reservaRef, {
          'creadoEn': FieldValue.serverTimestamp(),
          'dniViajero': widget.dniPasajero ?? '',
          'estado': 'confirmada',
          'monto': 15,
          'nombreViajero': nombreFinal,      // ← usa nombreFinal
          'numeroAsiento': numeroAsiento,
          'paradero': widget.paradero,
          'pasajeroUid': user?.uid ?? '',
          'viajeId': widget.viajeId,
          'codigoVerificacion': codigoUnico,
          'ruta': rutaFinal,
        });
      });

      // ── NUEVO: limpia el nombre del acompañante tras guardar ─────────────
      setState(() => _nombreAcompanante = null);

      if (!mounted) return;
      _mostrarCodigoExitoso(codigoUnico, nombreFinal, reservaId);
    } catch (e) {
      if (mounted) _mostrarError(e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NUEVO: pide nombre completo del acompañante con validación
  // ─────────────────────────────────────────────────────────────────────────
  void _pedirNombreAcompanante() {
    _nombreAcompananteCtrl.clear();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Datos del acompañante',
            style: TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ingresa el nombre completo del acompañante',
                  style:
                  TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreAcompananteCtrl,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  final partes = value
                      .trim()
                      .split(' ')
                      .where((p) => p.isNotEmpty)
                      .toList();
                  if (partes.length < 2) {
                    return 'Ingresa nombre Y apellido';
                  }
                  if (value.trim().length < 6) {
                    return 'Nombre demasiado corto';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Ej: Juan Pérez',
                  hintStyle: const TextStyle(color: Color(0xFF4B5563)),
                  prefixIcon: const Icon(Icons.person_outline,
                      color: Color(0xFF6B7280), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF0A0E1A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      const BorderSide(color: Color(0xFF1F2937))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      const BorderSide(color: Color(0xFF1F2937))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF1E6BFF), width: 1.5)),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      const BorderSide(color: Color(0xFFFF3B30))),
                  focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFFFF3B30), width: 1.5)),
                  errorStyle: const TextStyle(
                      color: Color(0xFFFF3B30), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                // Guarda el nombre y limpia el asiento para que
                // el usuario elija uno nuevo para el acompañante
                setState(() {
                  _nombreAcompanante =
                      _nombreAcompananteCtrl.text.trim();
                  _asientoSeleccionado = null;
                });
              }
            },
            child: const Text('Continuar',
                style: TextStyle(
                    color: Color(0xFF1E6BFF),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Seleccionar Asiento'),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('viajes').doc(widget.viajeId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child:
                CircularProgressIndicator(color: Color(0xFF1E6BFF)));
          }
          if (!snapshot.data!.exists) {
            return const Center(
                child: Text('Viaje no disponible.',
                    style: TextStyle(color: Colors.white)));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final ocupados =
          List<int>.from(data['asientosListaOcupados'] ?? []);

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('Distribución de Asientos Colectivo',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Capacidad máxima regulada: 4 Pasajeros',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Color(0xFF1E6BFF), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Recojo en: ${widget.paradero}',
                      style: const TextStyle(
                          color: Color(0xFF1E6BFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),

                // ── NUEVO: banner que muestra para quién se reserva ──────────
                if (_nombreAcompanante != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFF1E6BFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF1E6BFF)
                              .withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            color: Color(0xFF1E6BFF), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Reservando para: $_nombreAcompanante',
                            style: const TextStyle(
                                color: Color(0xFF1E6BFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceAround,
                        children: [
                          const Icon(
                              Icons.airline_seat_recline_normal,
                              color: Color(0xFF374151),
                              size: 42),
                          _buildBotonAsiento(1, ocupados),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(
                          color: Color(0xFF1F2937), thickness: 1.5),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceAround,
                        children: [
                          _buildBotonAsiento(2, ocupados),
                          _buildBotonAsiento(3, ocupados),
                          _buildBotonAsiento(4, ocupados),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                    _asientoSeleccionado == null || _guardando
                        ? null
                        : () => _confirmarReserva(data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6BFF),
                      disabledBackgroundColor:
                      const Color(0xFF1F2937),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _guardando
                        ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Text('Confirmar Reserva y Asiento',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBotonAsiento(int numero, List<int> ocupados) {
    final estaOcupado = ocupados.contains(numero);
    final esMio = _asientoSeleccionado == numero;

    Color colorFondo = const Color(0xFF0A0E1A);
    Color colorTexto = Colors.white;
    BoxBorder borde = Border.all(color: const Color(0xFF374151));

    if (estaOcupado) {
      colorFondo = const Color(0xFFFF3B30).withOpacity(0.15);
      colorTexto = const Color(0xFFFF3B30);
      borde = Border.all(color: const Color(0xFFFF3B30));
    } else if (esMio) {
      colorFondo = const Color(0xFF1E6BFF);
      colorTexto = Colors.white;
      borde = Border.all(color: const Color(0xFF1E6BFF));
    }

    return GestureDetector(
      onTap: estaOcupado
          ? null
          : () => setState(() => _asientoSeleccionado = numero),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(14),
          border: borde,
        ),
        child: Center(
          child: Text('$numero',
              style: TextStyle(
                  color: colorTexto,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODIFICADO: recibe también el nombre para mostrarlo en el diálogo
  // ─────────────────────────────────────────────────────────────────────────
  void _mostrarCodigoExitoso(String codigo, String nombreReservado, String reservaId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('🎉 ¡Reserva Exitosa!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── NUEVO: muestra para quién es la reserva ──────────────
            Text(
              'Reserva para: $nombreReservado',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('Muestra este código al abordar el vehículo:',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 14)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(codigo,
                  style: const TextStyle(
                      color: Color(0xFF1E6BFF),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4)),
            ),
            const SizedBox(height: 16),
            const Text('¿Deseas agregar otro pasajero?',
                style: TextStyle(
                    color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ReservaDetalleView(
                    reservaId: reservaId,
                    codigo: codigo,
                    nombrePasajero: nombreReservado,
                  ),
                ),
              );
            },
            child: const Text('Listo',
                style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // ── NUEVO: pide nombre antes de elegir asiento ────────
              _pedirNombreAcompanante();
            },
            child: const Text('+ Agregar pasajero',
                style: TextStyle(
                    color: Color(0xFF1E6BFF),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  void _mostrarError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title:
        const Text('Error', style: TextStyle(color: Colors.white)),
        content:
        Text(msg, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
  }
}