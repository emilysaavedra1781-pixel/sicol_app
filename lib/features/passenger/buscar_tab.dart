import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'paraderos_constants.dart';
import 'colectivo_detalle_view.dart';

class BuscarTab extends StatefulWidget {
  const BuscarTab({super.key});

  @override
  State<BuscarTab> createState() => _BuscarTabState();
}

class _BuscarTabState extends State<BuscarTab> {
  final _db = FirebaseFirestore.instance;

  String? _rutaSeleccionada;
  String? _paraderoSeleccionado;

  List<String> get _paraderosActuales =>
      _rutaSeleccionada != null ? paraderosPorRuta[_rutaSeleccionada!]! : [];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E6BFF), Color(0xFF0A4BCC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.directions_bus_rounded, color: Colors.white, size: 36),
                  SizedBox(height: 10),
                  Text('¿A dónde vas hoy?',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Ruta Carretera Central',
                      style: TextStyle(color: Color(0xFFBFD7FF), fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSelectorRuta(),
            const SizedBox(height: 24),
            if (_rutaSeleccionada != null && _paraderoSeleccionado != null)
              _buildListaColectivos(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorRuta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¿A dónde vas?',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            _botonRuta(label: 'Chosica → Lima', valor: 'chosica_lima', icono: Icons.arrow_forward_rounded),
            const SizedBox(width: 10),
            _botonRuta(label: 'Lima → Chosica', valor: 'lima_chosica', icono: Icons.arrow_back_rounded),
          ],
        ),
        if (_rutaSeleccionada != null) ...[
          const SizedBox(height: 14),
          const Text('Tu paradero de recojo',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _paraderoSeleccionado,
                hint: const Text('Elige tu paradero',
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 14)),
                dropdownColor: const Color(0xFF111827),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: _paraderosActuales
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) => setState(() => _paraderoSeleccionado = val),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _botonRuta({required String label, required String valor, required IconData icono}) {
    final sel = _rutaSeleccionada == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _rutaSeleccionada = valor;
          _paraderoSeleccionado = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF1E6BFF) : const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? const Color(0xFF1E6BFF) : const Color(0xFF1F2937)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: sel ? Colors.white : const Color(0xFF6B7280), size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                        color: sel ? Colors.white : const Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaColectivos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Colectivos disponibles',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E6BFF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _rutaSeleccionada == 'chosica_lima' ? 'Chosica → Lima' : 'Lima → Chosica',
                style: const TextStyle(color: Color(0xFF1E6BFF), fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('viajes')
              .where('estado', isEqualTo: 'activo')
              .where('ruta', isEqualTo: _rutaSeleccionada)
              .snapshots(),
          builder: (context, snapRuta) {
            return StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('viajes')
                  .where('estado', isEqualTo: 'activo')
                  .where('ruta', isNull: true)
                  .snapshots(),
              builder: (context, snapNulos) {
                if (!snapRuta.hasData || !snapNulos.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
                }

                final mapaViajes = <String, DocumentSnapshot>{};
                for (final doc in snapRuta.data!.docs) mapaViajes[doc.id] = doc;
                for (final doc in snapNulos.data!.docs) mapaViajes[doc.id] = doc;
                final viajes = mapaViajes.values.toList();

                if (viajes.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.directions_bus_outlined, color: Color(0xFF374151), size: 40),
                        SizedBox(height: 10),
                        Text('No hay colectivos disponibles para esta ruta',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                      ],
                    ),
                  );
                }

                return Column(
                  children: viajes.map((doc) {
                    final viaje = doc.data() as Map<String, dynamic>;
                    final rutaLabel = viaje['rutaLabel'] ??
                        (_rutaSeleccionada == 'chosica_lima' ? 'Chosica → Lima' : 'Lima → Chosica');
                    final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 4;
                    final asientosOcupados = (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
                    final libres = capacidad - asientosOcupados;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(rutaLabel,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E6BFF).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('S/ 15.00',
                                    style: TextStyle(
                                        color: Color(0xFF1E6BFF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF1E6BFF)),
                              const SizedBox(width: 4),
                              Text('Recojo en: $_paraderoSeleccionado',
                                  style: const TextStyle(
                                      color: Color(0xFF1E6BFF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.event_seat_rounded,
                                  size: 14,
                                  color: libres > 0 ? const Color(0xFF10B981) : const Color(0xFFFF3B30)),
                              const SizedBox(width: 4),
                              Text('$libres asiento(s) disponible(s)',
                                  style: TextStyle(
                                      color: libres > 0 ? const Color(0xFF10B981) : const Color(0xFFFF3B30),
                                      fontSize: 12)),
                              const SizedBox(width: 12),
                              const Icon(Icons.person_outline, size: 14, color: Color(0xFF6B7280)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(viaje['conductorNombre'] ?? 'Conductor',
                                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: libres > 0
                                  ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ColectivoDetalleView(
                                    viajeId: doc.id,
                                    paradero: _paraderoSeleccionado!,
                                    rutaSeleccionada: _rutaSeleccionada,
                                  ),
                                ),
                              )
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E6BFF),
                                disabledBackgroundColor: const Color(0xFF1F2937),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.confirmation_number_rounded, size: 16),
                              label: Text(
                                libres > 0 ? 'Reservar asiento' : 'Sin asientos disponibles',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }
}