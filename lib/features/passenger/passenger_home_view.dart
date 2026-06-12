import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/booking_service.dart';
import 'seat_selection_view.dart';
import 'colectivo_detalle_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paraderos fijos por ruta
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, List<String>> _paraderosPorRuta = {
  'chosica_lima': [
    'Plaza de Armas de Chosica',
    'Ñaña',
    'Huachipa',
    'Ate Vitarte',
    'La Molina',
    'Javier Prado',
    'Petit Thouars',
  ],
  'lima_chosica': [
    'Petit Thouars',
    'Javier Prado',
    'La Molina',
    'Ate Vitarte',
    'Huachipa',
    'Ñaña',
    'Plaza de Armas de Chosica',
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// PassengerHomeView — 3 tabs: Buscar / Mis Reservas / Perfil
// ─────────────────────────────────────────────────────────────────────────────
class PassengerHomeView extends StatefulWidget {
  const PassengerHomeView({super.key});

  @override
  State<PassengerHomeView> createState() => _PassengerHomeViewState();
}

class _PassengerHomeViewState extends State<PassengerHomeView> {
  final _db    = FirebaseFirestore.instance;
  final _auth  = FirebaseAuth.instance;
  final _bookingService = BookingService();

  int _tabIndex = 0;

  // ── Estado Tab 1: Buscar ──────────────────────────────────────────────────
  String? _rutaSeleccionada;
  String? _paraderoSeleccionado;

  List<String> get _paraderosActuales =>
      _rutaSeleccionada != null ? _paraderosPorRuta[_rutaSeleccionada!]! : [];

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        final uid = snapshot.data?.uid ?? '';

        if (uid.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0E1A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1E6BFF)),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          body: IndexedStack(
            index: _tabIndex,
            children: [
              _buildBuscarTab(),
              _buildReservasTab(uid),
              _buildPerfilTab(uid),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _tabIndex,
            onTap: (i) => setState(() => _tabIndex = i),
            backgroundColor: const Color(0xFF111827),
            selectedItemColor: const Color(0xFF1E6BFF),
            unselectedItemColor: const Color(0xFF6B7280),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded), label: 'Buscar'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.confirmation_number_rounded),
                  label: 'Mis Reservas'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded), label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1 — BUSCAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBuscarTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                  Icon(Icons.directions_bus_rounded,
                      color: Colors.white, size: 36),
                  SizedBox(height: 10),
                  Text('¿A dónde vas hoy?',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Ruta Carretera Central',
                      style: TextStyle(
                          color: Color(0xFFBFD7FF), fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Selector ruta + paradero
            _buildSelectorRuta(),
            const SizedBox(height: 24),

            // Lista colectivos (solo si hay ruta Y paradero)
            if (_rutaSeleccionada != null && _paraderoSeleccionado != null)
              _buildListaColectivos(),
          ],
        ),
      ),
    );
  }

  // ── Selector ruta ─────────────────────────────────────────────────────────
  Widget _buildSelectorRuta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¿A dónde vas?',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            _botonRuta(
                label: 'Chosica → Lima',
                valor: 'chosica_lima',
                icono: Icons.arrow_forward_rounded),
            const SizedBox(width: 10),
            _botonRuta(
                label: 'Lima → Chosica',
                valor: 'lima_chosica',
                icono: Icons.arrow_back_rounded),
          ],
        ),
        if (_rutaSeleccionada != null) ...[
          const SizedBox(height: 14),
          const Text('Tu paradero de recojo',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
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
                    style: TextStyle(
                        color: Color(0xFF4B5563), fontSize: 14)),
                dropdownColor: const Color(0xFF111827),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF6B7280)),
                style:
                const TextStyle(color: Colors.white, fontSize: 14),
                items: _paraderosActuales
                    .map((p) =>
                    DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _paraderoSeleccionado = val),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _botonRuta(
      {required String label,
        required String valor,
        required IconData icono}) {
    final sel = _rutaSeleccionada == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _rutaSeleccionada = valor;
          _paraderoSeleccionado = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: sel
                ? const Color(0xFF1E6BFF)
                : const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: sel
                    ? const Color(0xFF1E6BFF)
                    : const Color(0xFF1F2937)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono,
                  color: sel ? Colors.white : const Color(0xFF6B7280),
                  size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                      color: sel
                          ? Colors.white
                          : const Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Lista colectivos disponibles ──────────────────────────────────────────
  // Dos queries en paralelo:
  //   1. viajes con ruta ya asignada == _rutaSeleccionada
  //   2. viajes con ruta == null (aún sin asignar, disponibles para cualquier ruta)
  // Se combinan y deduplicán por doc.id
  Widget _buildListaColectivos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Colectivos disponibles',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E6BFF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _rutaSeleccionada == 'chosica_lima'
                    ? 'Chosica → Lima'
                    : 'Lima → Chosica',
                style: const TextStyle(
                    color: Color(0xFF1E6BFF), fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // StreamBuilder sobre los viajes con ruta ya asignada
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('viajes')
              .where('estado', isEqualTo: 'activo')
              .where('ruta', isEqualTo: _rutaSeleccionada)
              .snapshots(),
          builder: (context, snapRuta) {
            // StreamBuilder sobre los viajes sin ruta asignada aún
            return StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('viajes')
                  .where('estado', isEqualTo: 'activo')
                  .where('ruta', isNull: true)
                  .snapshots(),
              builder: (context, snapNulos) {
                if (!snapRuta.hasData || !snapNulos.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF1E6BFF)));
                }

                // Combinar y deduplicar por doc.id
                final mapaViajes = <String, DocumentSnapshot>{};
                for (final doc in snapRuta.data!.docs) {
                  mapaViajes[doc.id] = doc;
                }
                for (final doc in snapNulos.data!.docs) {
                  mapaViajes[doc.id] = doc;
                }
                final viajes = mapaViajes.values.toList();

                if (viajes.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                      border:
                      Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.directions_bus_outlined,
                            color: Color(0xFF374151), size: 40),
                        SizedBox(height: 10),
                        Text(
                            'No hay colectivos disponibles para esta ruta',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13)),
                      ],
                    ),
                  );
                }

                return Column(
                  children: viajes.map((doc) {
                    final viaje =
                    doc.data() as Map<String, dynamic>;
                    // Si el viaje aún no tiene ruta asignada,
                    // mostramos el label de la ruta seleccionada
                    final rutaLabel = viaje['rutaLabel'] ??
                        (_rutaSeleccionada == 'chosica_lima'
                            ? 'Chosica → Lima'
                            : 'Lima → Chosica');
                    final capacidad =
                        (viaje['capacidad'] as num?)?.toInt() ?? 4;
                    final asientosOcupados =
                        (viaje['asientosOcupados'] as num?)?.toInt() ??
                            0;
                    final libres = capacidad - asientosOcupados;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF1F2937)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(rutaLabel,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E6BFF)
                                      .withValues(alpha: 0.15),
                                  borderRadius:
                                  BorderRadius.circular(8),
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
                              const Icon(Icons.location_on_rounded,
                                  size: 13,
                                  color: Color(0xFF1E6BFF)),
                              const SizedBox(width: 4),
                              Text(
                                  'Recojo en: $_paraderoSeleccionado',
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
                                  color: libres > 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFFF3B30)),
                              const SizedBox(width: 4),
                              Text(
                                  '$libres asiento(s) disponible(s)',
                                  style: TextStyle(
                                      color: libres > 0
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFFF3B30),
                                      fontSize: 12)),
                              const SizedBox(width: 12),
                              const Icon(Icons.person_outline,
                                  size: 14,
                                  color: Color(0xFF6B7280)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                    viaje['conductorNombre'] ??
                                        'Conductor',
                                    style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 12),
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
                                backgroundColor:
                                const Color(0xFF1E6BFF),
                                disabledBackgroundColor:
                                const Color(0xFF1F2937),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: const Icon(
                                  Icons.confirmation_number_rounded,
                                  size: 16),
                              label: Text(
                                libres > 0
                                    ? 'Reservar asiento'
                                    : 'Sin asientos disponibles',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2 — MIS RESERVAS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildReservasTab(String uid) {
    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('reservas')
            .where('pasajeroUid', isEqualTo: uid)
            .where('estado', isEqualTo: 'confirmada')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1E6BFF)));
          }
          final reservas = snapshot.data!.docs;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mis reservas',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E6BFF)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${reservas.length} activa(s)',
                            style: const TextStyle(
                                color: Color(0xFF1E6BFF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              if (reservas.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                            Icons.confirmation_number_outlined,
                            color: Color(0xFF374151),
                            size: 56),
                        const SizedBox(height: 12),
                        const Text('No tienes reservas activas',
                            style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 14)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              setState(() => _tabIndex = 0),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF1E6BFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.search_rounded,
                              size: 16),
                          label: const Text('Buscar colectivo'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (ctx, i) =>
                        _buildReservaCard(reservas[i]),
                    childCount: reservas.length,
                  ),
                ),
              const SliverToBoxAdapter(
                  child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  // ── Card de reserva ───────────────────────────────────────────────────────
  Widget _buildReservaCard(DocumentSnapshot doc) {
    final res    = doc.data() as Map<String, dynamic>;
    final asiento = res['numeroAsiento'] ?? '-';
    final codigo  = res['codigoVerificacion'] ?? '-----';
    final viajeId = res['viajeId'] ?? '';
    final paradero = res['paradero'] ?? '-';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.confirmation_number_rounded,
                    color: Color(0xFF1E6BFF), size: 18),
                const SizedBox(width: 8),
                Text('Asiento $asiento',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('CONFIRMADA',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on_outlined,
                size: 13, color: Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Text('Paradero: $paradero',
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 12)),
          ]),
          const SizedBox(height: 12),

          // Código OTP
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF1E6BFF)
                      .withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text('CÓDIGO DE VERIFICACIÓN',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(codigo,
                    style: const TextStyle(
                        color: Color(0xFF1E6BFF),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6)),
                const SizedBox(height: 4),
                const Text('Muéstralo al conductor al abordar',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Botones dinámicos según estado del viaje
          StreamBuilder<DocumentSnapshot>(
            stream: _db.collection('viajes').doc(viajeId).snapshots(),
            builder: (context, viajeSnap) {
              if (!viajeSnap.hasData || !viajeSnap.data!.exists) {
                return const SizedBox();
              }
              final vData =
              viajeSnap.data!.data() as Map<String, dynamic>;
              final estadoViaje = vData['estado'] ?? 'activo';
              final enCamino = estadoViaje == 'en_camino';

              return Column(
                children: [
                  // ── Mapa en tiempo real (visible automáticamente en_camino) ──
                  if (enCamino) ...[
                    _MapaSeguimientoInline(viajeId: viajeId),
                    const SizedBox(height: 10),
                  ],

                  // ── Botones de acción ──
                  Row(
                    children: [
                      if (enCamino) ...[
                        // Ya bajé → libera asiento + marca finalizada
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _yaBaje(
                              doc.id,
                              viajeId,
                              asiento is int
                                  ? asiento
                                  : int.tryParse(
                                  asiento.toString()) ??
                                  0,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                              const Color(0xFF10B981),
                              side: const BorderSide(
                                  color: Color(0xFF10B981),
                                  width: 1),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10)),
                            ),
                            icon: const Icon(
                                Icons.check_circle_outline,
                                size: 14),
                            label: const Text('Ya bajé',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Ver mapa en modal (opcional, adicional)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _abrirMapaModal(context, viajeId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981)
                                  .withValues(alpha: 0.1),
                              foregroundColor:
                              const Color(0xFF10B981),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.fullscreen_rounded,
                                size: 14),
                            label: const Text('Ver completo',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ] else ...[
                        // Aún no arrancó → solo cancelar
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _cancelarReserva(
                              doc.id,
                              viajeId,
                              asiento is int
                                  ? asiento
                                  : int.tryParse(
                                  asiento.toString()) ??
                                  0,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                              const Color(0xFFFF3B30),
                              side: const BorderSide(
                                  color: Color(0xFFFF3B30), width: 1),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.cancel_outlined,
                                size: 14),
                            label: const Text('Cancelar reserva',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3 — PERFIL
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPerfilTab(String uid) {
    if (uid.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E6BFF)),
      );
    }
    return SafeArea(
      child: FutureBuilder<DocumentSnapshot>(
        future: _db.collection('usuarios').doc(uid).get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1E6BFF)));
          }

          final data =
          snap.hasData && snap.data!.exists
              ? (snap.data!.data() as Map<String, dynamic>)
              : <String, dynamic>{};

          final nombre = data['nombre'] ?? '';
          final apellido = data['apellido'] ?? '';
          final email = data['email'] ?? '-';
          final foto     = data['fotoUrl'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Tarjeta de perfil ─────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E6BFF), Color(0xFF0A4BCC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          image: foto != null
                              ? DecorationImage(
                              image: NetworkImage(foto),
                              fit: BoxFit.cover)
                              : null,
                        ),
                        child: foto == null
                            ? const Icon(Icons.person_rounded,
                            color: Colors.white, size: 32)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$nombre $apellido'.trim().isEmpty
                                  ? 'Pasajero'
                                  : '$nombre $apellido',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(email,
                                style: const TextStyle(
                                    color: Color(0xFFBFD7FF),
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Stats de viajes ───────────────────────────────────
                _buildStatsViajes(uid),
                const SizedBox(height: 20),

                // ── Datos personales ──────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border:
                    Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Datos personales',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      _itemPerfil(
                          Icons.person_outline,
                          'Nombre',
                          '$nombre $apellido'.trim().isEmpty
                              ? '-'
                              : '$nombre $apellido'),
                      _itemPerfil(
                          Icons.email_outlined, 'Email', email),
                      if (data['celular'] != null)
                        _itemPerfil(Icons.phone_outlined, 'Celular',
                            data['celular']),
                      if (data['dni'] != null)
                        _itemPerfil(Icons.badge_outlined, 'DNI',
                            data['dni']),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Cerrar sesión ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _auth.signOut(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF3B30),
                      side: const BorderSide(
                          color: Color(0xFFFF3B30), width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Cerrar sesión',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsViajes(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('reservas')
          .where('pasajeroUid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final todas  = snap.data?.docs ?? [];
        final activas    = todas.where((d) =>
        (d.data() as Map)['estado'] == 'confirmada').length;
        final completadas = todas.where((d) {
          final e = (d.data() as Map)['estado'];
          return e == 'finalizada' || e == 'completada';
        }).length;
        final canceladas = todas.where((d) =>
        (d.data() as Map)['estado'] == 'cancelada').length;

        return Row(
          children: [
            _statCard('Activas', '$activas',
                const Color(0xFF1E6BFF), Icons.confirmation_number_rounded),
            const SizedBox(width: 10),
            _statCard('Completadas', '$completadas',
                const Color(0xFF10B981), Icons.check_circle_rounded),
            const SizedBox(width: 10),
            _statCard('Canceladas', '$canceladas',
                const Color(0xFFFF3B30), Icons.cancel_rounded),
          ],
        );
      },
    );
  }

  Widget _statCard(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border:
          Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _itemPerfil(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B7280), size: 16),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  /// FIX: libera el asiento en Firestore Y marca la reserva como 'finalizada'
  Future<void> _yaBaje(
      String reservaId, String viajeId, int numeroAsiento) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Ya bajaste?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Confirma que ya saliste del colectivo.',
            style: TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No',
                  style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, ya bajé',
                  style: TextStyle(color: Color(0xFF10B981)))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final viajeRef  = _db.collection('viajes').doc(viajeId);
      final reservaRef = _db.collection('reservas').doc(reservaId);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(viajeRef);
        if (!snap.exists) return;

        final data = snap.data()!;
        final asientosMapa =
        Map<String, dynamic>.from(data['asientos'] ?? {});
        final key = 'asiento_$numeroAsiento';

        // Liberar asiento en el mapa
        asientosMapa[key] = {
          'numero': numeroAsiento,
          'estado': 'libre',
          'pasajero': null,
        };

        // Quitar de la lista de ocupados
        final ocupadosLista =
        List<int>.from(data['asientosListaOcupados'] ?? []);
        ocupadosLista.remove(numeroAsiento);

        tx.update(viajeRef, {
          'asientos': asientosMapa,
          'asientosListaOcupados': ocupadosLista,
          'asientosOcupados': ocupadosLista.length,
        });

        // Marcar reserva como finalizada
        tx.update(reservaRef, {'estado': 'finalizada'});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Hasta la próxima! Asiento liberado.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFFF3B30)),
        );
      }
    }
  }

  Future<void> _cancelarReserva(
      String reservaId, String viajeId, int numeroAsiento) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar reserva',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            '¿Deseas cancelar esta reserva? Se liberará el asiento.',
            style: TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No',
                  style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, cancelar',
                  style: TextStyle(color: Color(0xFFFF3B30)))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _bookingService.cancelarReserva(
          reservaId: reservaId,
          viajeId: viajeId,
          numeroAsiento: numeroAsiento,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Reserva cancelada'),
                backgroundColor: Color(0xFF10B981)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: const Color(0xFFFF3B30)),
          );
        }
      }
    }
  }

  /// Abre el mapa en un modal de pantalla completa
  void _abrirMapaModal(BuildContext context, String viajeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.80,
        child: _MapaSeguimientoWidget(viajeId: viajeId),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mapa inline embebido DENTRO de la card de reserva (compacto, solo lectura)
// Aparece automáticamente cuando el viaje está en_camino
// ─────────────────────────────────────────────────────────────────────────────
class _MapaSeguimientoInline extends StatefulWidget {
  final String viajeId;
  const _MapaSeguimientoInline({required this.viajeId});

  @override
  State<_MapaSeguimientoInline> createState() =>
      _MapaSeguimientoInlineState();
}

class _MapaSeguimientoInlineState
    extends State<_MapaSeguimientoInline> {
  GoogleMapController? _ctrl;
  final _db = FirebaseFirestore.instance;

  static const List<LatLng> _rutaChosicaLima = [
    LatLng(-11.9347, -76.6952),
    LatLng(-11.9280, -76.6750),
    LatLng(-11.9100, -76.6300),
    LatLng(-11.8900, -76.5800),
    LatLng(-11.9050, -76.9900),
    LatLng(-12.0200, -76.9500),
    LatLng(-12.0400, -76.9800),
    LatLng(-12.0650, -77.0000),
    LatLng(-12.0850, -77.0200),
    LatLng(-12.0900, -77.0350),
    LatLng(-12.0950, -77.0450),
  ];

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('viajes').doc(widget.viajeId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox(
            height: 160,
            child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1E6BFF))),
          );
        }

        final viaje = snap.data!.data() as Map<String, dynamic>;
        final ubicacion =
        (viaje['ubicacionActual'] as Map?)?.cast<String, dynamic>();
        final ruta = viaje['ruta'] ?? 'chosica_lima';

        final lat =
            (ubicacion?['lat'] as num?)?.toDouble() ?? -11.9347;
        final lng =
            (ubicacion?['lng'] as num?)?.toDouble() ?? -76.6952;
        final pos = LatLng(lat, lng);

        final puntos = ruta == 'chosica_lima'
            ? _rutaChosicaLima
            : _rutaChosicaLima.reversed.toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ctrl?.animateCamera(CameraUpdate.newLatLng(pos));
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Etiqueta "En vivo"
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.circle,
                      color: Color(0xFF10B981), size: 8),
                  SizedBox(width: 4),
                  Text('Colectivo en vivo',
                      style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),

            // Mapa compacto
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                child: GoogleMap(
                  initialCameraPosition:
                  CameraPosition(target: pos, zoom: 12),
                  onMapCreated: (c) => _ctrl = c,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  markers: {
                    Marker(
                      markerId: const MarkerId('colectivo'),
                      position: pos,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue),
                      infoWindow:
                      const InfoWindow(title: 'Colectivo'),
                    ),
                    Marker(
                      markerId: const MarkerId('destino'),
                      position: puntos.last,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed),
                      infoWindow:
                      const InfoWindow(title: 'Destino'),
                    ),
                  },
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('ruta'),
                      points: puntos,
                      color: const Color(0xFF1E6BFF),
                      width: 4,
                      patterns: [
                        PatternItem.dash(20),
                        PatternItem.gap(10)
                      ],
                    ),
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mapa de seguimiento en modal (pantalla casi completa)
// ─────────────────────────────────────────────────────────────────────────────
class _MapaSeguimientoWidget extends StatefulWidget {
  final String viajeId;
  const _MapaSeguimientoWidget({required this.viajeId});

  @override
  State<_MapaSeguimientoWidget> createState() =>
      _MapaSeguimientoWidgetState();
}

class _MapaSeguimientoWidgetState
    extends State<_MapaSeguimientoWidget> {
  GoogleMapController? _mapController;
  final _db = FirebaseFirestore.instance;

  static const List<LatLng> _rutaChosicaLima = [
    LatLng(-11.9347, -76.6952),
    LatLng(-11.9280, -76.6750),
    LatLng(-11.9100, -76.6300),
    LatLng(-11.8900, -76.5800),
    LatLng(-11.9050, -76.9900),
    LatLng(-12.0200, -76.9500),
    LatLng(-12.0400, -76.9800),
    LatLng(-12.0650, -77.0000),
    LatLng(-12.0850, -77.0200),
    LatLng(-12.0900, -77.0350),
    LatLng(-12.0950, -77.0450),
  ];

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('viajes').doc(widget.viajeId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
              child:
              CircularProgressIndicator(color: Color(0xFF1E6BFF)));
        }

        final viaje =
        snapshot.data!.data() as Map<String, dynamic>;
        final ubicacion =
        (viaje['ubicacionActual'] as Map?)?.cast<String, dynamic>();
        final ruta     = viaje['ruta'] ?? 'chosica_lima';
        final rutaLabel = viaje['rutaLabel'] ?? '';

        final lat =
            (ubicacion?['lat'] as num?)?.toDouble() ?? -11.9347;
        final lng =
            (ubicacion?['lng'] as num?)?.toDouble() ?? -76.6952;
        final posActual = LatLng(lat, lng);

        final rutaPuntos = ruta == 'chosica_lima'
            ? _rutaChosicaLima
            : _rutaChosicaLima.reversed.toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController?.animateCamera(
              CameraUpdate.newLatLng(posActual));
        });

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed,
                      color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(rutaLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.circle,
                          color: Color(0xFF10B981), size: 8),
                      SizedBox(width: 4),
                      Text('En vivo',
                          style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: GoogleMap(
                  initialCameraPosition:
                  CameraPosition(target: posActual, zoom: 13),
                  onMapCreated: (c) => _mapController = c,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  markers: {
                    Marker(
                      markerId: const MarkerId('colectivo'),
                      position: posActual,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue),
                      infoWindow:
                      const InfoWindow(title: 'Colectivo'),
                    ),
                    Marker(
                      markerId: const MarkerId('destino'),
                      position: rutaPuntos.last,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed),
                      infoWindow:
                      const InfoWindow(title: 'Destino'),
                    ),
                  },
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('ruta'),
                      points: rutaPuntos,
                      color: const Color(0xFF1E6BFF),
                      width: 4,
                      patterns: [
                        PatternItem.dash(20),
                        PatternItem.gap(10)
                      ],
                    ),
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}