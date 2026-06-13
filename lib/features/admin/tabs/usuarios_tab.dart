import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsuariosTab extends StatefulWidget {
  final FirebaseFirestore db;
  final Function(String, String, bool) onToggle;

  const UsuariosTab({super.key, required this.db, required this.onToggle});

  @override
  State<UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<UsuariosTab> {
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
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
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _filtroRol == 'todos'
                ? widget.db.collection('usuarios').snapshots()
                : widget.db
                .collection('usuarios')
                .where('rol', isEqualTo: _filtroRol)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
              }

              var docs = snapshot.data?.docs ?? [];

              if (_queryBuscador.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nom =
                  '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.toLowerCase();
                  final dni = (data['dni'] ?? '').toString().toLowerCase();
                  return nom.contains(_queryBuscador) || dni.contains(_queryBuscador);
                }).toList();
              }

              if (docs.isEmpty) {
                return const Center(
                  child: Text('No se encontraron usuarios',
                      style: TextStyle(color: Color(0xFF6B7280))),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
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
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          rol == 'conductor' ? Icons.drive_eta : Icons.person,
                          color: rol == 'conductor'
                              ? const Color(0xFF1E6BFF)
                              : const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombre,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              Text(
                                'DNI: ${data['dni'] ?? '-'} • Cel: ${data['celular'] ?? '-'}',
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 12),
                              ),
                              if (bloqueado)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Motivo: ${data['motivoBloqueo'] ?? 'No especificado'}',
                                    style: const TextStyle(
                                        color: Color(0xFFFF3B30),
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            bloqueado ? Icons.lock_open : Icons.lock,
                            color: bloqueado
                                ? const Color(0xFF10B981)
                                : const Color(0xFFFF3B30),
                          ),
                          onPressed: () => widget.onToggle(uid, nombre, bloqueado),
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

  Widget _chip(String v, String l) {
    final active = _filtroRol == v;
    return GestureDetector(
      onTap: () => setState(() => _filtroRol = v),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E6BFF) : const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          l,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF6B7280),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}