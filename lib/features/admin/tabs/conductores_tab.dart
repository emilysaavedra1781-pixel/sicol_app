import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/auth_service.dart';

class ConductoresTab extends StatefulWidget {
  final AuthService authService;
  final FirebaseFirestore db;
  final Function(String, String) onAprobar;
  final Function(String, String) onRechazar;

  const ConductoresTab({
    super.key,
    required this.authService,
    required this.db,
    required this.onAprobar,
    required this.onRechazar,
  });

  @override
  State<ConductoresTab> createState() => _ConductoresTabState();
}

class _ConductoresTabState extends State<ConductoresTab>
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
            tabs: const [
              Tab(text: 'Pendientes de Validación'),
              Tab(text: 'Conductores Oficiales'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: [_buildPendientes(), _buildAprobados()],
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
                Text('Todos los conductores validados',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ],
            ),
          );
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
            child: Text('No hay conductores activos',
                style: TextStyle(color: Color(0xFF6B7280))),
          );
        }

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

  Widget _conductorCard(
      Map<String, dynamic> data,
      String uid, {
        required bool pendiente,
        required String nombre,
      }) {
    final vehiculo = (data['vehiculo'] as Map?)?.cast<String, dynamic>() ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: pendiente
                ? const Color(0xFFF59E0B).withOpacity(0.05)
                : const Color(0xFF10B981).withOpacity(0.05),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: pendiente ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                Text(
                  pendiente ? 'POR REVISAR' : 'CÓDIGO: ${data['codigoConductor'] ?? '-'}',
                  style: TextStyle(
                    color: pendiente ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                _infoRow(Icons.commute, 'Modelo',
                    '${vehiculo['marca'] ?? ''} ${vehiculo['modelo'] ?? ''}'),
              ],
            ),
          ),
          if (pendiente)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => widget.onRechazar(uid, nombre),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF3B30),
                        side: const BorderSide(color: Color(0xFFFF3B30)),
                      ),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onAprobar(uid, nombre),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Validar e Inscribir'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B7280), size: 14),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          Expanded(child: Text(val, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }
}