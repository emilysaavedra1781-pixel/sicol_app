import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../auth/login/login_view.dart';

class AdminHomeView extends StatefulWidget {
  const AdminHomeView({super.key});

  @override
  State<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<AdminHomeView> {
  final _authService = AuthService();
  final _db = FirebaseFirestore.instance;
  int _tabIndex = 0;

  // 0=Dashboard, 1=Conductores, 2=Usuarios, 3=Viajes

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?',
            style: TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _authService.signOut();
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginView()), (r) => false);
    }
  }

  Future<void> _aprobar(String uid, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Aprobar conductor', style: TextStyle(color: Colors.white)),
        content: Text('¿Aprobar la cuenta de $nombre?',
            style: const TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aprobar', style: TextStyle(color: Color(0xFF10B981))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final codigo = await _authService.aprobarConductor(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $nombre aprobado. Código: $codigo'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _rechazar(String uid, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rechazar conductor', style: TextStyle(color: Colors.white)),
        content: Text('¿Rechazar la cuenta de $nombre?',
            style: const TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _authService.rechazarConductor(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Cuenta de $nombre rechazada.'),
        backgroundColor: const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _toggleUsuario(String uid, String nombre, bool bloqueado) async {
    final accion = bloqueado ? 'habilitar' : 'bloquear';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${accion[0].toUpperCase()}${accion.substring(1)} usuario',
            style: const TextStyle(color: Colors.white)),
        content: Text('¿Deseas $accion la cuenta de $nombre?',
            style: const TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(accion[0].toUpperCase() + accion.substring(1),
                style: TextStyle(
                    color: bloqueado
                        ? const Color(0xFF10B981)
                        : const Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.collection('usuarios').doc(uid).update({
        'estado': bloqueado ? 'activo' : 'bloqueado',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('SICOL — Admin',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF6B7280)),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Nav tabs ──────────────────────────────────────────────────────
          Container(
            color: const Color(0xFF111827),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tab(0, Icons.dashboard_rounded, 'Dashboard'),
                  _tab(1, Icons.drive_eta_rounded, 'Conductores'),
                  _tab(2, Icons.people_rounded, 'Usuarios'),
                  _tab(3, Icons.map_rounded, 'Viajes'),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _DashboardTab(db: _db),
                _ConductoresTab(
                  authService: _authService,
                  db: _db,
                  onAprobar: _aprobar,
                  onRechazar: _rechazar,
                ),
                _UsuariosTab(db: _db, onToggle: _toggleUsuario),
                _ViajesTab(db: _db),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(int index, IconData icon, String label) {
    final active = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF1E6BFF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: active ? const Color(0xFF1E6BFF) : const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: active ? const Color(0xFF1E6BFF) : const Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Dashboard (RF29)
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _DashboardTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen del día',
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // ── Indicadores en tiempo real ────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: db.collection('viajes').where('estado', isEqualTo: 'activo').snapshots(),
            builder: (context, snapActivos) {
              return StreamBuilder<QuerySnapshot>(
                stream: db.collection('viajes').where('estado', isEqualTo: 'finalizado').snapshots(),
                builder: (context, snapFinalizados) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: db.collection('reservas').where('estado', isEqualTo: 'confirmada').snapshots(),
                    builder: (context, snapReservas) {

                      final activos = snapActivos.data?.docs.length ?? 0;
                      final finalizados = snapFinalizados.data?.docs.length ?? 0;
                      final reservas = snapReservas.data?.docs ?? [];

                      // Calcular ingresos totales
                      double ingresos = 0;
                      for (final r in reservas) {
                        final data = r.data() as Map<String, dynamic>;
                        ingresos += (data['monto'] as num?)?.toDouble() ?? 0;
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _indicador(
                                  icon: Icons.directions_car_rounded,
                                  label: 'Viajes activos',
                                  valor: '$activos',
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _indicador(
                                  icon: Icons.check_circle_rounded,
                                  label: 'Finalizados',
                                  valor: '$finalizados',
                                  color: const Color(0xFF1E6BFF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _indicador(
                                  icon: Icons.people_rounded,
                                  label: 'Pasajeros hoy',
                                  valor: '${reservas.length}',
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _indicador(
                                  icon: Icons.attach_money_rounded,
                                  label: 'Ingresos',
                                  valor: 'S/ ${ingresos.toStringAsFixed(0)}',
                                  color: const Color(0xFF8B5CF6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),
          const Text('Viajes activos ahora',
              style: TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // ── Lista viajes activos ──────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: db.collection('viajes').where('estado', isEqualTo: 'activo').snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.directions_car_outlined,
                          color: Color(0xFF374151), size: 40),
                      SizedBox(height: 8),
                      Text('No hay viajes activos',
                          style: TextStyle(color: Color(0xFF6B7280))),
                    ],
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final ocupados = (d['asientosOcupados'] as num?)?.toInt() ?? 0;
                  final capacidad = (d['capacidad'] as num?)?.toInt() ?? 4;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.directions_car_rounded,
                              color: Color(0xFF10B981), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['rutaLabel'] ?? '-',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                '${d['conductorNombre'] ?? '-'} • $ocupados/$capacidad asientos',
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Activo',
                              style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _indicador({
    required IconData icon,
    required String label,
    required String valor,
    required Color color,
  }) {
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(valor,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Conductores (RF26)
// ─────────────────────────────────────────────────────────────────────────────

class _ConductoresTab extends StatefulWidget {
  final AuthService authService;
  final FirebaseFirestore db;
  final Function(String, String) onAprobar;
  final Function(String, String) onRechazar;

  const _ConductoresTab({
    required this.authService,
    required this.db,
    required this.onAprobar,
    required this.onRechazar,
  });

  @override
  State<_ConductoresTab> createState() => _ConductoresTabState();
}

class _ConductoresTabState extends State<_ConductoresTab>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF111827),
          child: TabBar(
            controller: _tc,
            indicatorColor: const Color(0xFF1E6BFF),
            labelColor: const Color(0xFF1E6BFF),
            unselectedLabelColor: const Color(0xFF6B7280),
            tabs: const [Tab(text: 'Pendientes'), Tab(text: 'Aprobados')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: [
              _buildPendientes(),
              _buildAprobados(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendientes() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.authService.getConductoresPendientes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 56),
                SizedBox(height: 16),
                Text('No hay conductores pendientes',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = docs[i].id;
            final nombre = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}';
            return _conductorCard(data, uid, pendiente: true, nombre: nombre);
          },
        );
      },
    );
  }

  Widget _buildAprobados() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db
          .collection('usuarios')
          .where('rol', isEqualTo: 'conductor')
          .where('estado', isEqualTo: 'activo')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.drive_eta_outlined, color: Color(0xFF6B7280), size: 56),
                SizedBox(height: 16),
                Text('No hay conductores aprobados',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = docs[i].id;
            final nombre = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}';
            return _conductorCard(data, uid, pendiente: false, nombre: nombre);
          },
        );
      },
    );
  }

  Widget _conductorCard(Map<String, dynamic> data, String uid,
      {required bool pendiente, required String nombre}) {
    final vehiculo = (data['vehiculo'] as Map?)?.cast<String, dynamic>() ?? {};
    final codigo = data['codigoConductor'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pendiente
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                  : const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: pendiente
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                        : const Color(0xFF10B981).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person,
                      color: pendiente
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                      size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      Text(
                        pendiente
                            ? 'Pendiente de aprobación'
                            : 'Código: ${codigo ?? '-'}',
                        style: TextStyle(
                            color: pendiente
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(Icons.badge_outlined, 'DNI', data['dni'] ?? '-'),
                _infoRow(Icons.phone_outlined, 'Celular', data['celular'] ?? '-'),
                _infoRow(Icons.card_membership_outlined, 'Licencia',
                    data['numeroLicencia'] ?? '-'),
                _infoRow(Icons.directions_car_outlined, 'Placa',
                    vehiculo['placa'] ?? '-'),
                _infoRow(Icons.directions_car_outlined, 'Vehículo',
                    '${vehiculo['marca'] ?? ''} ${vehiculo['modelo'] ?? ''}'),
                _infoRow(Icons.people_outline, 'Capacidad',
                    '${vehiculo['capacidad'] ?? '-'} pasajeros'),
              ],
            ),
          ),
          if (pendiente)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => widget.onRechazar(uid, nombre),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF3B30),
                        side: const BorderSide(color: Color(0xFFFF3B30)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Rechazar',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onAprobar(uid, nombre),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Aprobar',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B7280), size: 16),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3: Gestión de usuarios (RF21)
// ─────────────────────────────────────────────────────────────────────────────

class _UsuariosTab extends StatefulWidget {
  final FirebaseFirestore db;
  final Function(String, String, bool) onToggle;
  const _UsuariosTab({required this.db, required this.onToggle});

  @override
  State<_UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<_UsuariosTab> {
  String _filtro = 'todos'; // todos, pasajero, conductor

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtros
        Container(
          color: const Color(0xFF111827),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _filtroChip('todos', 'Todos'),
              const SizedBox(width: 8),
              _filtroChip('pasajero', 'Pasajeros'),
              const SizedBox(width: 8),
              _filtroChip('conductor', 'Conductores'),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _filtro == 'todos'
                ? widget.db.collection('usuarios').snapshots()
                : widget.db
                .collection('usuarios')
                .where('rol', isEqualTo: _filtro)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('No hay usuarios',
                      style: TextStyle(color: Color(0xFF6B7280))),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final uid = docs[i].id;
                  final nombre =
                  '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
                  final rol = data['rol'] ?? 'pasajero';
                  final estado = data['estado'] ?? 'activo';
                  final bloqueado = estado == 'bloqueado';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (rol == 'conductor'
                                ? const Color(0xFF1E6BFF)
                                : const Color(0xFF8B5CF6))
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            rol == 'conductor'
                                ? Icons.drive_eta_rounded
                                : Icons.person_rounded,
                            color: rol == 'conductor'
                                ? const Color(0xFF1E6BFF)
                                : const Color(0xFF8B5CF6),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombre.isEmpty ? 'Sin nombre' : nombre,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                '${rol[0].toUpperCase()}${rol.substring(1)} • ${data['celular'] ?? '-'}',
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => widget.onToggle(uid, nombre, bloqueado),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: (bloqueado
                                  ? const Color(0xFFFF3B30)
                                  : const Color(0xFF10B981))
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              bloqueado ? 'Bloqueado' : 'Activo',
                              style: TextStyle(
                                  color: bloqueado
                                      ? const Color(0xFFFF3B30)
                                      : const Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filtroChip(String value, String label) {
    final active = _filtro == value;
    return GestureDetector(
      onTap: () => setState(() => _filtro = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF1E6BFF).withValues(alpha: 0.15)
              : const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? const Color(0xFF1E6BFF) : Colors.transparent),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? const Color(0xFF1E6BFF) : const Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4: Monitoreo de viajes (RF22)
// ─────────────────────────────────────────────────────────────────────────────

class _ViajesTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _ViajesTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('viajes')
          .where('estado', isEqualTo: 'activo')
          .snapshots(),
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
                Icon(Icons.map_outlined, color: Color(0xFF374151), size: 56),
                SizedBox(height: 16),
                Text('No hay viajes activos',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('Los viajes en curso aparecerán aquí',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final vehiculo =
                (data['vehiculo'] as Map?)?.cast<String, dynamic>() ?? {};
            final ocupados = (data['asientosOcupados'] as num?)?.toInt() ?? 0;
            final capacidad = (data['capacidad'] as num?)?.toInt() ?? 4;
            final asientos =
                (data['asientos'] as Map?)?.cast<String, dynamic>() ?? {};

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.directions_car_rounded,
                              color: Color(0xFF10B981), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['rutaLabel'] ?? '-',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              Text(data['conductorNombre'] ?? '-',
                                  style: const TextStyle(
                                      color: Color(0xFF6B7280), fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('En curso',
                              style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  // Info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _chip(Icons.directions_car_outlined,
                                vehiculo['placa'] ?? '-'),
                            const SizedBox(width: 8),
                            _chip(Icons.people_outline,
                                '$ocupados/$capacidad pasajeros'),
                            const SizedBox(width: 8),
                            _chip(Icons.attach_money_rounded,
                                'S/ ${(data['ingresoTotal'] as num?)?.toInt() ?? 0}'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Mini grid asientos
                        const Text('Asientos',
                            style: TextStyle(
                                color: Color(0xFF6B7280), fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List.generate(capacidad, (idx) {
                            final key = 'asiento_${idx + 1}';
                            final asiento = (asientos[key] as Map?)
                                ?.cast<String, dynamic>() ??
                                {};
                            final estado = asiento['estado'] ?? 'libre';
                            final color = estado == 'ocupado'
                                ? const Color(0xFF1E6BFF)
                                : const Color(0xFF10B981);
                            return Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.4)),
                              ),
                              child: Center(
                                child: Text('${idx + 1}',
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF6B7280), size: 12),
          const SizedBox(width: 4),
          Text(label,
              style:
              const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        ],
      ),
    );
  }
}