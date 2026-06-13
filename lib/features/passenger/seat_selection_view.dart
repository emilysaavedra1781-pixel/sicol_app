import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reserva_detalle_view.dart';

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

  // Nombre del pasajero principal (se pide al entrar)
  String? _nombrePasajero;
  bool _nombreConfirmado = false;
  final _nombrePasajeroCtrl = TextEditingController();

  // Acompañante
  String? _nombreAcompanante;
  final _nombreAcompananteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Si ya viene el nombre del pasajero, lo usamos directamente
    if (widget.nombrePasajero != null && widget.nombrePasajero!.isNotEmpty) {
      _nombrePasajero = widget.nombrePasajero;
      _nombreConfirmado = true;
    } else {
      // Pedimos el nombre al usuario al entrar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pedirNombrePasajero();
      });
    }
  }

  @override
  void dispose() {
    _nombrePasajeroCtrl.dispose();
    _nombreAcompananteCtrl.dispose();
    super.dispose();
  }

  String _generarCodigoOTP() {
    const caracteres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
        5, (_) => caracteres[random.nextInt(caracteres.length)]).join();
  }

  // ── Pedir nombre del pasajero principal ─────────────────────────────────
  void _pedirNombrePasajero() {
    _nombrePasajeroCtrl.clear();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tu nombre completo',
            style: TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa tu nombre completo para la reserva',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombrePasajeroCtrl,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  final partes = value
                      .trim()
                      .split(' ')
                      .where((p) => p.isNotEmpty)
                      .toList();
                  if (partes.length < 2) return 'Ingresa nombre Y apellido';
                  if (value.trim().length < 6) return 'Nombre demasiado corto';
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
                      borderSide: const BorderSide(color: Color(0xFF1F2937))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1F2937))),
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
                  errorStyle:
                  const TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Si cancela, regresa
            },
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _nombrePasajero = _nombrePasajeroCtrl.text.trim();
                  _nombreConfirmado = true;
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E6BFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Continuar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Verificar que el usuario ya tiene reserva propia ────────────────────
  Future<bool> _tieneReservaPropia() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snap = await _db
        .collection('reservas')
        .where('viajeId', isEqualTo: widget.viajeId)
        .where('pasajeroUid', isEqualTo: user.uid)
        .where('estado', isEqualTo: 'confirmada')
        .limit(1)
        .get();

    // Solo cuenta si hay una reserva donde el nombre coincide con el pasajero principal
    // (no acompañantes — los acompañantes también tienen el mismo pasajeroUid)
    // Filtramos por nombreViajero == nombre del usuario principal guardado
    return snap.docs.any((doc) {
      final data = doc.data();
      // Si tiene el mismo uid y el nombre es el del usuario (no un acompañante)
      // Para detectarlo usamos el campo esAcompanante que agregamos
      return data['esAcompanante'] != true;
    });
  }

  // ── Pedir nombre del acompañante ─────────────────────────────────────────
  Future<void> _pedirNombreAcompanante() async {
    // Verificar que el usuario ya tiene su propia reserva
    final tienePropia = await _tieneReservaPropia();

    if (!tienePropia) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Reserva tu asiento primero',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'Debes reservar tu propio asiento antes de agregar un acompañante.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E6BFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

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
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreAcompananteCtrl,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  final partes = value
                      .trim()
                      .split(' ')
                      .where((p) => p.isNotEmpty)
                      .toList();
                  if (partes.length < 2) return 'Ingresa nombre Y apellido';
                  if (value.trim().length < 6) return 'Nombre demasiado corto';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Ej: María García',
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
                  errorStyle:
                  const TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
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
                setState(() {
                  _nombreAcompanante = _nombreAcompananteCtrl.text.trim();
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

  Future<void> _confirmarReserva(Map<String, dynamic> viajeData) async {
    if (_asientoSeleccionado == null || _guardando) return;
    if (!_nombreConfirmado || _nombrePasajero == null) {
      _pedirNombrePasajero();
      return;
    }

    final nombreFinal = _nombreAcompanante ?? _nombrePasajero!;
    final esAcompanante = _nombreAcompanante != null;

    // ── Simulación de pago ────────────────────────────────────────────────
    final pagoConfirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.payment_rounded, color: Color(0xFF1E6BFF), size: 22),
            SizedBox(width: 8),
            Text('Confirmar pago', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF1E6BFF).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('MONTO A PAGAR',
                      style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('S/ 15.00',
                      style: TextStyle(
                          color: Color(0xFF1E6BFF),
                          fontSize: 32,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'Asiento $_asientoSeleccionado · ${widget.paradero}',
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pasajero: $nombreFinal',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '¿Deseas confirmar el pago de S/ 15.00?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
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
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Pagar S/ 15.00',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (pagoConfirmado != true) return;

    setState(() => _guardando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final codigoUnico = _generarCodigoOTP();
      final numeroAsiento = _asientoSeleccionado!;
      final key = 'asiento_$numeroAsiento';

      final reservaRef = _db.collection('reservas').doc();
      final reservaId = reservaRef.id;

      await _db.runTransaction((transaction) async {
        final viajeRef = _db.collection('viajes').doc(widget.viajeId);
        final viajeSnap = await transaction.get(viajeRef);

        if (!viajeSnap.exists) {
          throw Exception('El viaje ya no está disponible.');
        }

        final data = viajeSnap.data()!;
        final capacidad = (data['capacidad'] as num?)?.toInt() ?? 4;
        final ocupadosLista =
        List<int>.from(data['asientosListaOcupados'] ?? []);

        if (numeroAsiento > capacidad) {
          throw Exception(
              'El asiento $numeroAsiento no existe en este vehículo.');
        }

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

        if (ocupadosLista.length >= capacidad) {
          throw Exception(
              'No quedan asientos disponibles en este colectivo.');
        }

        ocupadosLista.add(numeroAsiento);
        asientosMapa[key] = {
          'numero': numeroAsiento,
          'estado': 'ocupado',
          'pasajero': {
            'uid': user?.uid ?? '',
            'nombre': nombreFinal,
            'dni': widget.dniPasajero ?? '',
            'paradero': widget.paradero,
            'asiento': numeroAsiento,
          },
        };

        final rutaActual = data['ruta'];
        final rutaFinal = rutaActual ?? widget.rutaSeleccionada;
        final rutaLabelFinal = rutaActual != null
            ? data['rutaLabel']
            : _rutaLabels[widget.rutaSeleccionada] ?? widget.rutaSeleccionada;

        transaction.update(viajeRef, {
          'asientosListaOcupados': ocupadosLista,
          'asientos': asientosMapa,
          'asientosOcupados': ocupadosLista.length,
          'ingresoTotal': FieldValue.increment(15),
          if (rutaActual == null) 'ruta': rutaFinal,
          if (rutaActual == null) 'rutaLabel': rutaLabelFinal,
        });

        transaction.set(reservaRef, {
          'creadoEn': FieldValue.serverTimestamp(),
          'dniViajero': widget.dniPasajero ?? '',
          'estado': 'confirmada',
          'monto': 15,
          'nombreViajero': nombreFinal,
          'numeroAsiento': numeroAsiento,
          'paradero': widget.paradero,
          'pasajeroUid': user?.uid ?? '',
          'viajeId': widget.viajeId,
          'codigoVerificacion': codigoUnico,
          'ruta': rutaFinal,
          'esAcompanante': esAcompanante, // ← NUEVO
        });
      });

      setState(() => _nombreAcompanante = null);

      if (!mounted) return;
      _mostrarCodigoExitoso(codigoUnico, nombreFinal, reservaId);
    } catch (e) {
      if (mounted) _mostrarError(e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Seleccionar Asiento'),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        foregroundColor: Colors.white,
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
          final capacidad = (data['capacidad'] as num?)?.toInt() ?? 4;
          final ocupados =
          List<int>.from(data['asientosListaOcupados'] ?? []);
          final libres = capacidad - ocupados.length;

          if (libres <= 0) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_seat_rounded,
                      color: Color(0xFFFF3B30), size: 56),
                  const SizedBox(height: 12),
                  const Text('No hay asientos disponibles',
                      style:
                      TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Este colectivo está lleno.',
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('Distribución de Asientos',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Capacidad del vehículo: $capacidad pasajeros',
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Color(0xFF1E6BFF), size: 14),
                    const SizedBox(width: 4),
                    Text('Recojo en: ${widget.paradero}',
                        style: const TextStyle(
                            color: Color(0xFF1E6BFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),

                // Banner nombre pasajero principal
                if (_nombreConfirmado && _nombrePasajero != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF10B981)
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_rounded,
                            color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pasajero: $_nombrePasajero',
                            style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Banner acompañante
                if (_nombreAcompanante != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E6BFF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF1E6BFF)
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_add_rounded,
                            color: Color(0xFF1E6BFF), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Acompañante: $_nombreAcompanante',
                            style: const TextStyle(
                                color: Color(0xFF1E6BFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _nombreAcompanante = null),
                          child: const Icon(Icons.close_rounded,
                              color: Color(0xFF6B7280), size: 16),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Leyenda
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _leyendaItem(const Color(0xFF1E6BFF), 'Seleccionado'),
                    const SizedBox(width: 16),
                    _leyendaItem(const Color(0xFFFF3B30), 'Ocupado'),
                    const SizedBox(width: 16),
                    _leyendaItem(const Color(0xFF374151), 'Libre'),
                  ],
                ),
                const SizedBox(height: 16),

                // Grid de asientos
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(16),
                      border:
                      Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Column(
                              children: [
                                const Icon(
                                    Icons.airline_seat_recline_normal,
                                    color: Color(0xFF374151),
                                    size: 36),
                                const SizedBox(height: 4),
                                const Text('Conductor',
                                    style: TextStyle(
                                        color: Color(0xFF374151),
                                        fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(
                            color: Color(0xFF1F2937), thickness: 1),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.4,
                            ),
                            itemCount: capacidad,
                            itemBuilder: (context, index) {
                              final numero = index + 1;
                              return _buildBotonAsiento(
                                  numero, ocupados);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Botón agregar acompañante
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _pedirNombreAcompanante,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E6BFF),
                      side: const BorderSide(
                          color: Color(0xFF1E6BFF), width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: const Text('Reservar para acompañante',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 10),

                // Botón confirmar
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed:
                    _asientoSeleccionado == null || _guardando
                        ? null
                        : () => _confirmarReserva(data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6BFF),
                      disabledBackgroundColor: const Color(0xFF1F2937),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: _guardando
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.payment_rounded, size: 20),
                    label: Text(
                      _guardando
                          ? 'Procesando...'
                          : _asientoSeleccionado != null
                          ? 'Pagar S/ 15.00 · Asiento $_asientoSeleccionado'
                          : 'Selecciona un asiento',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBotonAsiento(int numero, List<int> ocupados) {
    final estaOcupado = ocupados.contains(numero);
    final esMio = _asientoSeleccionado == numero;

    Color colorFondo;
    Color colorTexto;
    Color colorBorde;
    IconData icono;

    if (estaOcupado) {
      colorFondo = const Color(0xFFFF3B30).withValues(alpha: 0.15);
      colorTexto = const Color(0xFFFF3B30);
      colorBorde = const Color(0xFFFF3B30);
      icono = Icons.person;
    } else if (esMio) {
      colorFondo = const Color(0xFF1E6BFF);
      colorTexto = Colors.white;
      colorBorde = const Color(0xFF1E6BFF);
      icono = Icons.check_rounded;
    } else {
      colorFondo = const Color(0xFF0A0E1A);
      colorTexto = Colors.white;
      colorBorde = const Color(0xFF374151);
      icono = Icons.event_seat_rounded;
    }

    return GestureDetector(
      onTap: estaOcupado
          ? null
          : () => setState(() => _asientoSeleccionado = numero),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorBorde, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: colorTexto, size: 24),
            const SizedBox(height: 6),
            Text(
              estaOcupado ? 'Ocupado' : 'Asiento $numero',
              style: TextStyle(
                  color: colorTexto,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leyendaItem(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration:
            BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 11)),
      ],
    );
  }

  void _mostrarCodigoExitoso(
      String codigo, String nombreReservado, String reservaId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Reserva exitosa',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 48),
            const SizedBox(height: 12),
            Text('Reserva para: $nombreReservado',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('Código de verificación:',
                style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF1E6BFF)
                        .withValues(alpha: 0.3)),
              ),
              child: Text(codigo,
                  style: const TextStyle(
                      color: Color(0xFF1E6BFF),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4)),
            ),
            const SizedBox(height: 14),
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
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
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

  void _mostrarError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Error',
            style: TextStyle(color: Colors.white)),
        content: Text(msg,
            style: const TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK',
                  style: TextStyle(color: Color(0xFF1E6BFF)))),
        ],
      ),
    );
  }
}