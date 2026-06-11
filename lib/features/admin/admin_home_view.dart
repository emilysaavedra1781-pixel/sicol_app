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

  // 0=Dashboard, 1=Conductores, 2=Usuarios, 3=Control Viajes, 4=Paraderos (RF55)

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
        content: Text('¿Aprobar la cuenta de $nombre después de validar físicamente sus documentos?',
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

  // REQUISITO RF21: Gestión de Usuarios con Motivo de Bloqueo Obligatorio
  Future<void> _toggleUsuario(String uid, String nombre, bool bloqueado) async {
    final txtMotivo = TextEditingController();
    final formKey = GlobalKey<FormState>();

    if (!bloqueado) {
      // Flujo de Bloqueo (Requiere explicación obligatoria)
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Bloquear cuenta de $nombre', style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Es obligatorio registrar el motivo de la sanción para auditoría del sistema.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: txtMotivo,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Motivo del bloqueo',
                    labelStyle: TextStyle(color: Color(0xFF6B7280)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1F2937))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1E6BFF))),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese un motivo válido' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Confirmar Bloqueo', style: TextStyle(color: Color(0xFFFF3B30))),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _db.collection('usuarios').doc(uid).update({
          'estado': 'bloqueado',
          'motivoBloqueo': txtMotivo.text.trim(),
          'fechaBloqueo': FieldValue.serverTimestamp(),
        });
      }
    } else {
      // Flujo de Desbloqueo directo
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Habilitar usuario', style: TextStyle(color: Colors.white)),
          content: Text('¿Deseas restaurar el acceso activo para $nombre?', style: const TextStyle(color: Color(0xFF6B7280))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280)))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reactivar', style: TextStyle(color: Color(0xFF10B981))),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _db.collection('usuarios').doc(uid).update({
          'estado': 'activo',
          'motivoBloqueo': FieldValue.delete(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('SICOL — Sistema de Control',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Color(0xFF6B7280)), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF111827),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tab(0, Icons.dashboard_rounded, 'Dashboard'),
                  _tab(1, Icons.drive_eta_rounded, 'Conductores'),
                  _tab(2, Icons.people_rounded, 'Usuarios'),
                  _tab(3, Icons.map_rounded, 'Control Viajes'),
                  _tab(4, Icons.add_location_alt_rounded, 'Paraderos (RF55)'),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _DashboardTab(db: _db),
                _ConductoresTab(authService: _authService, db: _db, onAprobar: _aprobar, onRechazar: _rechazar),
                _UsuariosTab(db: _db, onToggle: _toggleUsuario),
                _ViajesTab(db: _db),
                _ParaderosTab(db: _db), // Módulo de cumplimiento RF55 añadido
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
          border: Border(bottom: BorderSide(color: active ? const Color(0xFF1E6BFF) : Colors.transparent, width: 2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? const Color(0xFF1E6BFF) : const Color(0xFF6B7280)),
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
// Tab 1: Dashboard (RF29 - Métricas Diarias Automatizadas)
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _DashboardTab({required this.db});

  @override
  Widget build(BuildContext context) {
    // Definir rangos estrictos de hoy para cumplir RF29 sin mezclar datos históricos
    final ahora = DateTime.now();
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen operativo de hoy',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: db.collection('viajes').where('estado', isEqualTo: 'activo').snapshots(),
            builder: (context, snapActivos) {
              return StreamBuilder<QuerySnapshot>(
                stream: db.collection('viajes').where('estado', isEqualTo: 'finalizado').snapshots(),
                builder: (context, snapFinalizados) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: db.collection('reservas')
                        .where('estado', isEqualTo: 'confirmada')
                        .where('fechaCreacion', isGreaterThanOrEqualTo: inicioHoy)
                        .snapshots(),
                    builder: (context, snapReservas) {
                      final activos = snapActivos.data?.docs.length ?? 0;
                      final finalizados = snapFinalizados.data?.docs.length ?? 0;
                      final reservas = snapReservas.data?.docs ?? [];

                      double ingresos = 0;
                      for (final r in reservas) {
                        final data = r.data() as Map<String, dynamic>;
                        ingresos += (data['monto'] as num?)?.toDouble() ?? 0;
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _indicador(icon: Icons.directions_car_rounded, label: 'Colectivos en línea', valor: '$activos', color: const Color(0xFF10B981))),
                              const SizedBox(width: 12),
                              Expanded(child: _indicador(icon: Icons.check_circle_rounded, label: 'Viajes terminados', valor: '$finalizados', color: const Color(0xFF1E6BFF))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _indicador(icon: Icons.people_rounded, label: 'Pasajeros del día', valor: '${reservas.length}', color: const Color(0xFFF59E0B))),
                              const SizedBox(width: 12),
                              Expanded(child: _indicador(icon: Icons.attach_money_rounded, label: 'Ingresos diarios', valor: 'S/ ${ingresos.toStringAsFixed(2)}', color: const Color(0xFF8B5CF6))),
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
          const Text('Unidades en servicio activo', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: db.collection('viajes').where('estado', isEqualTo: 'activo').snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1F2937))),
                  child: const Column(
                    children: [
                      Icon(Icons.directions_car_outlined, color: Color(0xFF374151), size: 40),
                      SizedBox(height: 8),
                      Text('No hay colectivos activos en Carretera Central', style: TextStyle(color: Color(0xFF6B7280))),
                    ],
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final ocupados = (d['asientosOcupados'] as num?)?.toInt() ?? 0;
                  final capacidad = (d['capacidad'] as num?)?.toInt() ?? 4;
                  final esEspera = d['ruta'] == 'esperando';
                  final rutaTxt = esEspera ? 'Disponible (Esperando Asignación)' : (d['rutaLabel'] ?? '-');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1F2937))),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: (esEspera ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withOpacity(0.15), shape: BoxShape.circle),
                          child: Icon(Icons.directions_car_rounded, color: esEspera ? const Color(0xFFF59E0B) : const Color(0xFF10B981), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rutaTxt, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                              Text('${d['conductorNombre'] ?? 'Conductor'} • $ocupados/$capacidad asientos', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: (esEspera ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(esEspera ? 'Espera' : 'En Ruta', style: TextStyle(color: esEspera ? const Color(0xFFF59E0B) : const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
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

  Widget _indicador({required IconData icon, required String label, required String valor, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1F2937))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(valor, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Conductores (RF26 - Auditoría y Registro)
// ─────────────────────────────────────────────────────────────────────────────
class _ConductoresTab extends StatefulWidget {
  final AuthService authService;
  final FirebaseFirestore db;
  final Function(String, String) onAprobar;
  final Function(String, String) onRechazar;

  const _ConductoresTab({required this.authService, required this.db, required this.onAprobar, required this.onRechazar});

  @override
  State<_ConductoresTab> createState() => _ConductoresTabState();
}

class _ConductoresTabState extends State<_ConductoresTab> with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() { super.initState(); _tc = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

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
            tabs: const [Tab(text: 'Pendientes de Validación'), Tab(text: 'Conductores Oficiales')],
          ),
        ),
        Expanded(child: TabBarView(controller: _tc, children: [_buildPendientes(), _buildAprobados()])),
      ],
    );
  }

  Widget _buildPendientes() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.authService.getConductoresPendientes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 56), SizedBox(height: 16), Text('Todos los conductores validados', style: TextStyle(color: Colors.white, fontSize: 15))]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final nombre = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}';
            return _conductorCard(data, docs[i].id, pendiente: true, nombre: nombre);
          },
        );
      },
    );
  }

  Widget _buildAprobados() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db.collection('usuarios').where('rol', isEqualTo: 'conductor').where('estado', isEqualTo: 'activo').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No hay conductores activos', style: TextStyle(color: Color(0xFF6B7280))));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final nombre = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}';
            return _conductorCard(data, docs[i].id, pendiente: false, nombre: nombre);
          },
        );
      },
    );
  }

  Widget _conductorCard(Map<String, dynamic> data, String uid, {required bool pendiente, required String nombre}) {
    final vehiculo = (data['vehiculo'] as Map?)?.cast<String, dynamic>() ?? {};
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1F2937))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: pendiente ? const Color(0xFFF59E0B).withOpacity(0.05) : const Color(0xFF10B981).withOpacity(0.05),
            child: Row(
              children: [
                Icon(Icons.person, color: pendiente ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                const SizedBox(width: 10),
                Expanded(child: Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Text(pendiente ? 'POR REVISAR' : 'CÓDIGO: ${data['codigoConductor'] ?? '-'}', style: TextStyle(color: pendiente ? const Color(0xFFF59E0B) : const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _infoRow(Icons.badge, 'DNI', data['dni'] ?? '-'),
                _infoRow(Icons.phone, 'Celular', data['celular'] ?? '-'),
                _infoRow(Icons.card_membership, 'N° Licencia', data['numeroLicencia'] ?? '-'),
                _infoRow(Icons.directions_car, 'Placa Vehicular', vehiculo['placa'] ?? '-'),
                _infoRow(Icons.commute, 'Modelo', '${vehiculo['marca'] ?? ''} ${vehiculo['modelo'] ?? ''}'),
              ],
            ),
          ),
          if (pendiente)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => widget.onRechazar(uid, nombre), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF3B30), side: const BorderSide(color: Color(0xFFFF3B30))), child: const Text('Rechazar'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: () => widget.onAprobar(uid, nombre), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white), child: const Text('Validar e Inscribir'))),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [Icon(icon, color: const Color(0xFF6B7280), size: 14), const SizedBox(width: 8), Text('$label: ', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)), Expanded(child: Text(val, style: const TextStyle(color: Colors.white, fontSize: 13)))]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3: Gestión de Usuarios (RF21 - Buscador por Filtros de Entrada Coincidente)
// ─────────────────────────────────────────────────────────────────────────────
class _UsuariosTab extends StatefulWidget {
  final FirebaseFirestore db;
  final Function(String, String, bool) onToggle;
  const _UsuariosTab({required this.db, required this.onToggle});

  @override
  State<_UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<_UsuariosTab> {
  String _filtroRol = 'todos';
  String _queryBuscador = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF111827),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _queryBuscador = v.trim().toLowerCase()),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar usuario por DNI o Nombre...',
                  hintStyle: const TextStyle(color: Color(0xFF4B5563)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
                  filled: true,
                  fillColor: const Color(0xFF0A0E1A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip('todos', 'Todos'),
                  const SizedBox(width: 6),
                  _chip('pasajero', 'Pasajeros'),
                  const SizedBox(width: 6),
                  _chip('conductor', 'Conductores'),
                ],
              )
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _filtroRol == 'todos'
                ? widget.db.collection('usuarios').snapshots()
                : widget.db.collection('usuarios').where('rol', isEqualTo: _filtroRol).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
              var docs = snapshot.data?.docs ?? [];

              // Filtrar localmente por Nombre o DNI en tiempo real
              if (_queryBuscador.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nom = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.toLowerCase();
                  final dni = (data['dni'] ?? '').toString().toLowerCase();
                  return nom.contains(_queryBuscador) || dni.contains(_queryBuscador);
                }).toList();
              }

              if (docs.isEmpty) return const Center(child: Text('No se encontraron usuarios', style: TextStyle(color: Color(0xFF6B7280))));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final uid = docs[i].id;
                  final nombre = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
                  final rol = data['rol'] ?? 'pasajero';
                  final estado = data['estado'] ?? 'activo';
                  final bloqueado = estado == 'bloqueado';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
                    child: Row(
                      children: [
                        Icon(rol == 'conductor' ? Icons.drive_eta : Icons.person, color: rol == 'conductor' ? const Color(0xFF1E6BFF) : const Color(0xFF8B5CF6)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                              Text('DNI: ${data['dni'] ?? '-'} • Cel: ${data['celular'] ?? '-'}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                              if (bloqueado)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Motivo: ${data['motivoBloqueo'] ?? 'No especificado'}', style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 11, fontStyle: FontStyle.italic)),
                                )
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(bloqueado ? Icons.lock_open : Icons.lock, color: bloqueado ? const Color(0xFF10B981) : const Color(0xFFFF3B30)),
                          onPressed: () => widget.onToggle(uid, nombre, bloqueado),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }

  Widget _chip(String v, String l) {
    final active = _filtroRol == v;
    return GestureDetector(
      onTap: () => setState(() => _filtroRol = v),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: active ? const Color(0xFF1E6BFF) : const Color(0xFF1F2937), borderRadius: BorderRadius.circular(20)),
        child: Text(l, style: TextStyle(color: active ? Colors.white : const Color(0xFF6B7280), fontSize: 12)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4: Control Operativo Remoto de Viajes (Contingencia Administrativa)
// ─────────────────────────────────────────────────────────────────────────────
class _ViajesTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _ViajesTab({required this.db});

  Future<void> _liberarUnidadRetrasada(BuildContext context, String viajeId, String conductor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Forzar Cierre de Viaje', style: TextStyle(color: Colors.white)),
        content: Text('¿Deseas liberar de forma remota el vehículo de $conductor debido a un retraso prolongado o bloqueo operativo?', style: const TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30)), child: const Text('Liberar Unidad')),
        ],
      ),
    );
    if (confirm == true) {
      await db.collection('viajes').doc(viajeId).update({
        'estado': 'finalizado',
        'forzadoPorAdmin': true,
        'fechaFinalizacion': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unidad liberada en la red distributiva.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('viajes').where('estado', isEqualTo: 'activo').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No hay operaciones activas en este momento', style: TextStyle(color: Color(0xFF6B7280))));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final conductor = d['conductorNombre'] ?? 'Conductor';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(conductor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Ruta: ${d['ruta'] == 'esperando' ? 'Disponible en Espera' : (d['rutaLabel'] ?? '-')}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                      ]),
                      Text('${d['asientosOcupados'] ?? 0}/${d['capacidad'] ?? 4} Asientos', style: const TextStyle(color: Color(0xFF1E6BFF), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _liberarUnidadRetrasada(context, docs[i].id, conductor),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30).withOpacity(0.1), foregroundColor: const Color(0xFFFF3B30), elevation: 0),
                      icon: const Icon(Icons.flash_on, size: 14),
                      label: const Text('Forzar Arranque / Liberar por Retraso'),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 5: Gestión de Paraderos (CUMPLIMIENTO COMPLETO REQUISITO MANDATORIO RF55)
// ─────────────────────────────────────────────────────────────────────────────
class _ParaderosTab extends StatefulWidget {
  final FirebaseFirestore db;
  const _ParaderosTab({required this.db});

  @override
  State<_ParaderosTab> createState() => _ParaderosTabState();
}

class _ParaderosTabState extends State<_ParaderosTab> {
  String _rutaSeleccionada = 'Chosica a Lima'; // Únicas dos rutas fijas permitidas por negocio
  final _txtNombre = TextEditingController();
  final _txtReferencia = TextEditingController();
  final _txtOrden = TextEditingController();

  Future<void> _guardarParadero({String? docId, int? paraderosActivosCount, bool? currentStatus}) async {
    final nombre = _txtNombre.text.trim();
    final referencia = _txtReferencia.text.trim();
    final orden = int.tryParse(_txtOrden.text.trim()) ?? 1;

    if (nombre.isEmpty || referencia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Complete todos los campos requeridos.')));
      return;
    }

    if (docId == null) {
      // EXCEPCIÓN EA01: Validar duplicidad de nombre en la misma ruta antes de escribir
      final duplicado = await widget.db.collection('paraderos')
          .where('rutaId', isEqualTo: _rutaSeleccionada)
          .where('nombre', isEqualTo: nombre)
          .get();

      if (duplicado.docs.isNotEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF111827),
            title: const Text('Registro Denegado (EA01)', style: TextStyle(color: Colors.white)),
            content: Text('El paradero "$nombre" ya existe mapeado en la ruta $_rutaSeleccionada.', style: const TextStyle(color: Color(0xFF6B7280))),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
          ),
        );
        return;
      }

      // Guardar Paradero Nuevo
      await widget.db.collection('paraderos').add({
        'nombre': nombre,
        'referencia': referencia,
        'orden': orden,
        'rutaId': _rutaSeleccionada,
        'activo': true,
      });
    } else {
      // Editar existente
      await widget.db.collection('paraderos').doc(docId).update({
        'nombre': nombre,
        'referencia': referencia,
        'orden': orden,
      });
    }

    _txtNombre.clear(); _txtReferencia.clear(); _txtOrden.clear();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleEstadoParadero(String id, bool actual, int activosCount) async {
    // EXCEPCIÓN EA02: Evitar apagar el único paradero que mantiene viva la ruta
    if (actual == true && activosCount <= 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: const Text('Acción Bloqueada (EA02)', style: TextStyle(color: Colors.white)),
          content: const Text('Cada ruta fija debe contar con al menos un paradero activo en todo momento para los pasajeros.', style: TextStyle(color: Color(0xFF6B7280))),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
        ),
      );
      return;
    }

    await widget.db.collection('paraderos').doc(id).update({'activo': !actual});
  }

  void _abrirFormulario({String? docId, String? nom, String? ref, int? ord}) {
    if (docId != null) {
      _txtNombre.text = nom ?? '';
      _txtReferencia.text = ref ?? '';
      _txtOrden.text = ord?.toString() ?? '1';
    } else {
      _txtNombre.clear(); _txtReferencia.clear(); _txtOrden.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(docId == null ? 'Nuevo Paradero en Ruta' : 'Modificar Paradero', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(controller: _txtNombre, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nombre del punto (ej: Ovalo Santa Anita)', labelStyle: TextStyle(color: Color(0xFF6B7280)))),
            TextField(controller: _txtReferencia, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Referencia visual', labelStyle: TextStyle(color: Color(0xFF6B7280)))),
            TextField(controller: _txtOrden, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'N° de Posición de Secuencia (Orden)', labelStyle: TextStyle(color: Color(0xFF6B7280)))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _guardarParadero(docId: docId), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6BFF)), child: const Text('Guardar Paradero Fijo'))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF111827),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(label: const Text('Chosica → Lima'), selected: _rutaSeleccionada == 'Chosica a Lima', onSelected: (s) => setState(() => _rutaSeleccionada = 'Chosica a Lima')),
              const SizedBox(width: 12),
              ChoiceChip(label: const Text('Lima → Chosica'), selected: _rutaSeleccionada == 'Lima a Chosica', onSelected: (s) => setState(() => _rutaSeleccionada = 'Lima a Chosica')),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.db.collection('paraderos').where('rutaId', isEqualTo: _rutaSeleccionada).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data?.docs ?? [];

              // Calcular cuántos quedan activos actualmente en la ruta seleccionada para la regla de negocio
              final activosCount = docs.where((doc) => (doc.data() as Map<String, dynamic>)['activo'] == true).length;

              // Ordenar localmente por el índice de posición numérico asignado
              final listaOrdenada = docs.toList()..sort((a, b) {
                final ordA = (a.data() as Map<String, dynamic>)['orden'] ?? 99;
                final ordB = (b.data() as Map<String, dynamic>)['orden'] ?? 99;
                return ordA.compareTo(ordB);
              });

              if (listaOrdenada.isEmpty) return const Center(child: Text('Ningún paradero registrado en este tramo.', style: TextStyle(color: Color(0xFF6B7280))));

              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: listaOrdenada.length,
                itemBuilder: (context, i) {
                  final doc = listaOrdenada[i];
                  final d = doc.data() as Map<String, dynamic>;
                  final activo = d['activo'] ?? true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: activo ? const Color(0xFF1F2937) : const Color(0xFFFF3B30).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: activo ? const Color(0xFF1E6BFF).withOpacity(0.2) : const Color(0xFF374151), radius: 16, child: Text('${d['orden'] ?? i}', style: TextStyle(color: activo ? const Color(0xFF1E6BFF) : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d['nombre'] ?? '-', style: TextStyle(color: activo ? Colors.white : Colors.grey, fontWeight: FontWeight.w600, decoration: activo ? TextDecoration.none : TextDecoration.lineThrough)),
                            Text('Ref: ${d['referencia'] ?? '-'}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                          ]),
                        ),
                        IconButton(icon: const Icon(Icons.edit, color: Color(0xFF6B7280), size: 18), onPressed: () => _abrirFormulario(docId: doc.id, nom: d['nombre'], ref: d['referencia'], ord: d['orden'])),
                        IconButton(
                          icon: Icon(activo ? Icons.visibility : Icons.visibility_off, color: activo ? const Color(0xFF10B981) : const Color(0xFFFF3B30)),
                          onPressed: () => _toggleEstadoParadero(doc.id, activo, activosCount),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF111827),
          width: double.infinity,
          child: ElevatedButton.icon(onPressed: () => _abrirFormulario(), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6BFF)), icon: const Icon(Icons.add), label: const Text('Agregar Nuevo Paradero Fijo')),
        )
      ],
    );
  }
}