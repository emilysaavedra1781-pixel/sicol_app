import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../auth/login/login_view.dart';
import 'seat_selection_view.dart';

class PassengerHomeView extends StatefulWidget {
  const PassengerHomeView({super.key});

  @override
  State<PassengerHomeView> createState() => _PassengerHomeViewState();
}

class _PassengerHomeViewState extends State<PassengerHomeView> {
  final _bookingService = BookingService();
  int _tabIndex = 0; // 0 = Colectivos, 1 = Mis reservas

  // ─── Logout ───────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión',
                style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService().signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginView()),
            (route) => false,
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'SICOL — Pasajero',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF6B7280)),
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Tabs ──────────────────────────────────────────────────────────
          Container(
            color: const Color(0xFF111827),
            child: Row(
              children: [
                _tab(0, Icons.directions_car_rounded, 'Colectivos'),
                _tab(1, Icons.confirmation_number_outlined, 'Mis reservas'),
              ],
            ),
          ),
          // ── Contenido ─────────────────────────────────────────────────────
          Expanded(
            child: _tabIndex == 0
                ? _ColectivosTab(bookingService: _bookingService)
                : _ReservasTab(bookingService: _bookingService),
          ),
        ],
      ),
    );
  }

  Widget _tab(int index, IconData icon, String label) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active
                    ? const Color(0xFF1E6BFF)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: active
                      ? const Color(0xFF1E6BFF)
                      : const Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? const Color(0xFF1E6BFF)
                      : const Color(0xFF6B7280),
                  fontSize: 14,
                  fontWeight:
                  active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Colectivos disponibles (RF06)
// ─────────────────────────────────────────────────────────────────────────────

class _ColectivosTab extends StatelessWidget {
  final BookingService bookingService;
  const _ColectivosTab({required this.bookingService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: bookingService.getColectivosDisponibles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Color(0xFFFF3B30))),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car_outlined,
                    color: Color(0xFF374151), size: 56),
                SizedBox(height: 16),
                Text('No hay colectivos disponibles',
                    style:
                    TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('Vuelve a intentarlo más tarde',
                    style:
                    TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _ColectivoCard(
              viajeId: doc.id,
              data: data,
            );
          },
        );
      },
    );
  }
}

class _ColectivoCard extends StatelessWidget {
  final String viajeId;
  final Map<String, dynamic> data;

  const _ColectivoCard({required this.viajeId, required this.data});

  @override
  Widget build(BuildContext context) {
    final vehiculo = (data['vehiculo'] as Map?)?.cast<String, dynamic>() ?? {};
    final capacidad = (data['capacidad'] as num?)?.toInt() ?? 4;
    final asientosOcupados = (data['asientosOcupados'] as num?)?.toInt() ?? 0;
    final asientosLibres = capacidad - asientosOcupados;
    final rutaLabel = data['rutaLabel'] ?? data['ruta'] ?? 'Sin ruta';

    return GestureDetector(
      onTap: () {
        // Añadir rutaLabel al data si no existe
        final enrichedData = {
          ...data,
          'rutaLabel': rutaLabel,
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SeatSelectionView(
              viajeId: viajeId,
              viajeData: enrichedData,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ruta + asientos ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    rutaLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                _AsientosBadge(libres: asientosLibres, total: capacidad),
              ],
            ),
            const SizedBox(height: 12),
            // ── Detalles ─────────────────────────────────────────────────
            Row(
              children: [
                _detalle(Icons.directions_car_rounded,
                    vehiculo['placa'] ?? '-'),
                const SizedBox(width: 16),
                _detalle(Icons.person_outline,
                    data['conductorNombre'] ?? 'Conductor'),
                const SizedBox(width: 16),
                _detalle(Icons.attach_money_rounded, 'S/ 15.00'),
              ],
            ),
            const SizedBox(height: 14),
            // ── Barra de ocupación ────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$asientosOcupados/$capacidad ocupados',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 12)),
                    Text('$asientosLibres libres',
                        style: const TextStyle(
                            color: Color(0xFF10B981), fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: capacidad > 0 ? asientosOcupados / capacidad : 0,
                    backgroundColor: const Color(0xFF1F2937),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      asientosLibres == 0
                          ? const Color(0xFFFF3B30)
                          : const Color(0xFF1E6BFF),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Botón ─────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: asientosLibres > 0
                    ? () {
                  final enrichedData = {
                    ...data,
                    'rutaLabel': rutaLabel,
                  };
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SeatSelectionView(
                        viajeId: viajeId,
                        viajeData: enrichedData,
                      ),
                    ),
                  );
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6BFF),
                  disabledBackgroundColor: const Color(0xFF1F2937),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text(
                  asientosLibres > 0 ? 'Reservar asiento' : 'Sin asientos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: asientosLibres > 0
                        ? Colors.white
                        : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detalle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6B7280), size: 14),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 13)),
      ],
    );
  }
}

class _AsientosBadge extends StatelessWidget {
  final int libres;
  final int total;
  const _AsientosBadge({required this.libres, required this.total});

  @override
  Widget build(BuildContext context) {
    final color = libres == 0
        ? const Color(0xFFFF3B30)
        : libres <= 1
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$libres/$total asientos',
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Mis reservas (RF10)
// ─────────────────────────────────────────────────────────────────────────────

class _ReservasTab extends StatelessWidget {
  final BookingService bookingService;
  const _ReservasTab({required this.bookingService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: bookingService.getMisReservas(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.confirmation_number_outlined,
                    color: Color(0xFF374151), size: 56),
                SizedBox(height: 16),
                Text('No tienes reservas',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('Tus reservas confirmadas aparecerán aquí',
                    style:
                    TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final reservaId = docs[i].id;
            return _ReservaCard(
              reservaId: reservaId,
              data: data,
              bookingService: bookingService,
            );
          },
        );
      },
    );
  }
}

class _ReservaCard extends StatelessWidget {
  final String reservaId;
  final Map<String, dynamic> data;
  final BookingService bookingService;

  const _ReservaCard({
    required this.reservaId,
    required this.data,
    required this.bookingService,
  });

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'confirmada':
        return const Color(0xFF10B981);
      case 'cancelada':
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Future<void> _cancelar(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar reserva',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Al cancelar, el asiento se libera inmediatamente. No hay devoluciones.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await bookingService.cancelarReserva(
        reservaId: reservaId,
        viajeId: data['viajeId'],
        numeroAsiento: data['numeroAsiento'],
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = data['estado'] ?? 'confirmada';
    final estadoColor = _estadoColor(estado);
    final cancelable = estado == 'confirmada';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  data['viajeId'] ?? 'Viaje',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                  Border.all(color: estadoColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  estado[0].toUpperCase() + estado.substring(1),
                  style: TextStyle(
                      color: estadoColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1F2937), height: 1),
          const SizedBox(height: 12),
          // ── Detalles ─────────────────────────────────────────────────
          _fila('Viajero', data['nombreViajero'] ?? '-'),
          _fila('DNI', data['dniViajero'] ?? '-'),
          _fila('Asiento', '${data['numeroAsiento'] ?? '-'}'),
          _fila('Paradero', data['paradero'] ?? '-'),
          _fila('Monto', 'S/ ${((data['monto'] as num?) ?? 15.0).toStringAsFixed(2)}'),
          // ── Cancelar ─────────────────────────────────────────────────
          if (cancelable) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: () => _cancelar(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                  side: const BorderSide(
                      color: Color(0xFFFF3B30), width: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancelar reserva',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fila(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}