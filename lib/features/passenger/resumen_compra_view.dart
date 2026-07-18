import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/deep_link_service.dart';
import '../../app_theme.dart';

class ResumenCompraView extends StatefulWidget {
  final String reservaGroupId;
  final String viajeId;
  final List<int> asientos;
  final Map<int, String> viajerosNombres;
  final Map<int, String> viajerosDnis;
  final String paradero;
  final String initPoint;
  final Map<String, dynamic> viajeData;

  const ResumenCompraView({
    super.key,
    required this.reservaGroupId,
    required this.viajeId,
    required this.asientos,
    required this.viajerosNombres,
    required this.viajerosDnis,
    required this.paradero,
    required this.initPoint,
    required this.viajeData,
  });

  @override
  State<ResumenCompraView> createState() => _ResumenCompraViewState();
}

class _ResumenCompraViewState extends State<ResumenCompraView> {
  final _db = FirebaseFirestore.instance;
  bool _procesando = false;

  @override
  Widget build(BuildContext context) {
    final double montoTotal = widget.asientos.length * 15.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen de compra'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _cancelarReserva(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // CP04: Detectar expiración en tiempo real
        stream: _db.collection('reservas')
            .where('reservaGroupId', isEqualTo: widget.reservaGroupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty || docs.any((d) => d['estado'] == 'expirada')) {
            // Reserva expirada
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mostrarAlertaExpiracion();
            });
            return const Center(child: Text('Reserva expirada'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('DATOS DEL VIAJE'),
                const SizedBox(height: 16),
                _buildInfoCard([
                  _buildRow('Conductor', widget.viajeData['conductorNombre'] ?? 'Sicol Conductor'),
                  _buildRow('Vehículo', '${widget.viajeData['vehiculo']?['marca'] ?? ''} - ${widget.viajeData['vehiculo']?['placa'] ?? ''}'),
                  _buildRow('Ruta', widget.viajeData['rutaLabel'] ?? 'Sicol Ruta'),
                  _buildRow('Punto de recojo', widget.paradero),
                ]),
                const SizedBox(height: 32),
                _buildSectionTitle('VIAJEROS Y ASIENTOS'),
                const SizedBox(height: 16),
                ...widget.asientos.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildInfoCard([
                    _buildRow('Asiento', n.toString()),
                    _buildRow('Nombre', widget.viajerosNombres[n] ?? ''),
                    _buildRow('DNI', widget.viajerosDnis[n] ?? ''),
                  ]),
                )),
                const SizedBox(height: 32),
                _buildSectionTitle('PAGO'),
                const SizedBox(height: 16),
                _buildInfoCard([
                  _buildRow('Precio por asiento', 'S/ 15.00'),
                  _buildRow('Total a pagar', 'S/ ${montoTotal.toStringAsFixed(2)}', isTotal: true),
                ]),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: _procesando ? null : _confirmarYPagar,
                  child: Text(_procesando ? 'REDIRECCIONANDO...' : 'CONFIRMAR Y PAGAR'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _cancelarReserva,
                    child: const Text('CANCELAR', style: TextStyle(color: CabifyColors.error, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: CabifyColors.primary, fontSize: 12, letterSpacing: 1));
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          Text(value, style: TextStyle(
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            fontSize: isTotal ? 18 : 14,
            color: isTotal ? CabifyColors.primary : const Color(0xFF111827),
          )),
        ],
      ),
    );
  }

  Future<void> _confirmarYPagar() async {
    setState(() => _procesando = true);
    try {
      // Guardar contexto para el ciclo de reservas múltiples al volver del deep link
      DeepLinkService().lastPurchaseContext = {
        'viajeId': widget.viajeId,
        'paradero': widget.paradero,
        'rutaSeleccionada': widget.viajeData['ruta'],
        'nombrePasajero': widget.viajerosNombres.values.first, // Simplificado para el diálogo
      };

      final Uri url = Uri.parse(widget.initPoint);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir el portal de pago.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: CabifyColors.error)
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _cancelarReserva() async {
    // CP03: Liberar asientos y volver
    try {
      final batch = _db.batch();
      
      // 1. Cambiar estado en el viaje
      final vRef = _db.collection('viajes').doc(widget.viajeId);
      final vSnap = await vRef.get();
      final vData = vSnap.data() as Map<String, dynamic>;
      final asientos = Map<String, dynamic>.from(vData['asientos'] ?? {});
      
      for (var n in widget.asientos) {
        final key = 'asiento_$n';
        if (asientos[key]?['estado'] == 'bloqueado') {
          asientos[key] = {
            'numero': n,
            'estado': 'libre',
            'pasajero': null,
          };
        }
      }
      batch.update(vRef, {'asientos': asientos});

      // 2. Eliminar reservas bloqueadas
      final resSnap = await _db.collection('reservas')
          .where('reservaGroupId', isEqualTo: widget.reservaGroupId)
          .get();
      
      for (var doc in resSnap.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error al cancelar reserva: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  void _mostrarAlertaExpiracion() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Tiempo expirado'),
        content: const Text('Tu tiempo de reserva expiró. Los asientos fueron liberados.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Cerrar diálogo
              Navigator.pop(context); // Volver a selección
            },
            child: const Text('ACEPTAR'),
          ),
        ],
      ),
    );
  }
}
