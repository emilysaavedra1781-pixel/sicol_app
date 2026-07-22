import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/booking_service.dart';
import '../../services/validation_service.dart';
import '../../app_theme.dart';
import 'resumen_compra_view.dart';

class SeatSelectionView extends StatefulWidget {
  final String viajeId;
  final String? nombrePasajero;
  final String paradero;
  final String? rutaSeleccionada;

  const SeatSelectionView({
    super.key,
    required this.viajeId,
    required this.paradero,
    this.nombrePasajero,
    this.rutaSeleccionada,
  });

  @override
  State<SeatSelectionView> createState() => _SeatSelectionViewState();
}

class _SeatSelectionViewState extends State<SeatSelectionView> {
  final Set<int> _asientosSeleccionados = {}; 
  final Map<int, String> _viajerosNombres = {}; 
  final Map<int, String> _viajerosDnis = {}; 
  
  final _db = FirebaseFirestore.instance;
  final _bookingService = BookingService();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _resetState();
  }

  void _resetState() {
    _asientosSeleccionados.clear();
    _viajerosNombres.clear();
    _viajerosDnis.clear();
    _guardando = false;
  }

  void _onSeatTap(int num, List<int> ocupados, Map<String, dynamic> asientosMapa) {
    final key = 'asiento_$num';
    final estado = asientosMapa[key]?['estado'] ?? 'libre';
    
    if (ocupados.contains(num) || estado != 'libre') return;

    setState(() {
      if (_asientosSeleccionados.contains(num)) {
        _asientosSeleccionados.remove(num);
        _viajerosNombres.remove(num);
        _viajerosDnis.remove(num);
      } else {
        _asientosSeleccionados.add(num);
      }
    });
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
        title: const Text('Elige tus asientos', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('viajes').doc(widget.viajeId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final capacidad = (data['capacidad'] as num?)?.toInt() ?? 4;
          final ocupados = List<int>.from(data['asientosListaOcupados'] ?? []);
          final asientosMapa = Map<String, dynamic>.from(data['asientos'] ?? {});

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('¿Dónde quieres ir?', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 8),
                Text('${capacidad - ocupados.length} asientos disponibles', 
                  style: const TextStyle(color: CabifyColors.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Column(
                                children: [
                                  Icon(Icons.airline_seat_recline_normal, color: Color(0xFFE5E7EB), size: 40),
                                  Text('CONDUCTOR', style: TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 40),
                          Expanded(
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                                childAspectRatio: 1.2,
                              ),
                              itemCount: capacidad,
                              itemBuilder: (ctx, i) => _buildSeat(i + 1, ocupados, asientosMapa),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_asientosSeleccionados.isNotEmpty)
                  ElevatedButton(
                    onPressed: _guardando ? null : () => _mostrarFormularioViajeros(data),
                    child: Text(_guardando ? 'PROCESANDO...' : 'CONTINUAR CON ${_asientosSeleccionados.length} ASIENTOS'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _mostrarFormularioViajeros(Map<String, dynamic> viajeData) async {
    final List<int> sortedAsientos = _asientosSeleccionados.toList()..sort();
    final user = FirebaseAuth.instance.currentUser;

    // Precargar datos del titular en el primer asiento seleccionado si aún están vacíos
    if (user != null && sortedAsientos.isNotEmpty) {
      final firstAsiento = sortedAsientos.first;
      if (_viajerosNombres[firstAsiento] == null || _viajerosNombres[firstAsiento]!.isEmpty) {
        final userDoc = await _db.collection('usuarios').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final nombreCompleto = '${userData['nombre'] ?? ''} ${userData['apellido'] ?? ''}'.trim();
          _viajerosNombres[firstAsiento] = nombreCompleto;
          _viajerosDnis[firstAsiento] = userData['dni'] ?? '';
        }
      }
    }

    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          bool valid = true;
          for(var n in sortedAsientos) {
            if (!ValidationService.esViajeroValido(_viajerosNombres[n], _viajerosDnis[n])) {
              valid = false;
            }
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Datos de los viajeros', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 24),
                  ...sortedAsientos.map((n) {
                    final isTitular = n == sortedAsientos.first;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('ASIENTO $n', style: const TextStyle(fontWeight: FontWeight.w800, color: CabifyColors.primary, fontSize: 12, letterSpacing: 1)),
                              if (isTitular) 
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Text('(Tú)', style: TextStyle(color: CabifyColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: _viajerosNombres[n],
                            onChanged: (v) => setModalState(() => _viajerosNombres[n] = v),
                            decoration: const InputDecoration(hintText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _viajerosDnis[n],
                            onChanged: (v) => setModalState(() => _viajerosDnis[n] = v),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                            decoration: const InputDecoration(hintText: 'DNI (8 dígitos)', prefixIcon: Icon(Icons.badge_outlined)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: !valid ? null : () {
                      Navigator.pop(ctx);
                      _bloquearYAvanzar(viajeData);
                    },
                    child: const Text('CONTINUAR'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Future<void> _bloquearYAvanzar(Map<String, dynamic> viajeData) async {
    setState(() => _guardando = true);
    
    try {
      final result = await _bookingService.bloquearAsientosYCrearPreferencia(
        viajeId: widget.viajeId,
        asientos: _asientosSeleccionados.toList(),
        viajeros: _asientosSeleccionados.map((n) => {
          'asiento': n,
          'nombre': _viajerosNombres[n],
          'dni': _viajerosDnis[n],
        }).toList(),
        monto: 15.0 * _asientosSeleccionados.length,
        paradero: widget.paradero,
      );

      if (result['success'] == true) {
        final String? initPoint = result['initPoint'];
        final String? reservaGroupId = result['reservaGroupId'];
        
        if (initPoint != null && reservaGroupId != null) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResumenCompraView(
                reservaGroupId: reservaGroupId,
                viajeId: widget.viajeId,
                asientos: _asientosSeleccionados.toList(),
                viajerosNombres: _viajerosNombres,
                viajerosDnis: _viajerosDnis,
                paradero: widget.paradero,
                initPoint: initPoint,
                viajeData: viajeData,
              ),
            ),
          );
        }
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll("Exception: ", "");
        
        if (errorMsg.contains("seats-occupied")) {
          errorMsg = "Uno de los asientos elegidos acaba de ser ocupado. Por favor elige otros.";
          _resetState();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg), 
            backgroundColor: CabifyColors.error,
            duration: const Duration(seconds: 4),
          )
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _buildSeat(int num, List<int> ocupados, Map<String, dynamic> asientosMapa) {
    final key = 'asiento_$num';
    final estado = asientosMapa[key]?['estado'] ?? 'libre';
    final estaOcupado = ocupados.contains(num) || estado == 'ocupado';
    final estaBloqueado = estado == 'bloqueado';
    final esMio = _asientosSeleccionados.contains(num);

    Color bgColor = Colors.white;
    Color iconColor = const Color(0xFFD1D5DB);
    Color textColor = const Color(0xFF9CA3AF);
    IconData icon = Icons.event_seat_rounded;
    String label = 'LIBRE';

    if (estaOcupado) {
      bgColor = CabifyColors.primary;
      iconColor = Colors.white;
      textColor = Colors.white;
      icon = Icons.person;
      label = 'OCUPADO';
    } else if (estaBloqueado) {
      bgColor = const Color(0xFFFFD60A); 
      iconColor = Colors.black87;
      textColor = Colors.black87;
      icon = Icons.lock_clock_rounded;
      label = 'PROCESO';
    } else if (esMio) {
      bgColor = CabifyColors.primary.withValues(alpha: 0.2);
      iconColor = CabifyColors.primary;
      textColor = CabifyColors.primary;
      label = 'ELEGIDO';
    }

    return GestureDetector(
      onTap: (estaOcupado || estaBloqueado) ? null : () => _onSeatTap(num, ocupados, asientosMapa),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (estaOcupado || estaBloqueado || esMio) ? (estaBloqueado ? const Color(0xFFFFD60A) : CabifyColors.primary) : const Color(0xFFE5E7EB),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
