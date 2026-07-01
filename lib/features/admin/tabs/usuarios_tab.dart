import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../app_theme.dart';

class UsuariosTab extends StatefulWidget {
  final FirebaseFirestore db;
  final void Function(String u, String n, bool b) onToggle;
  
  const UsuariosTab({super.key, required this.db, required this.onToggle});

  @override
  State<UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<UsuariosTab> {
  String _filtroRol = 'todos';
  String _filtroEstado = 'todos';
  String _queryBuscador = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtros y Búsqueda (CP02, CP03, CP04)
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _queryBuscador = v.trim().toLowerCase()),
                style: const TextStyle(color: CabifyColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Buscar por Nombre o DNI...',
                  hintStyle: const TextStyle(color: CabifyColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: CabifyColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _dropdownFilter(
                      label: 'TIPO',
                      value: _filtroRol,
                      items: ['todos', 'pasajero', 'conductor', 'admin'],
                      onChanged: (v) => setState(() => _filtroRol = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dropdownFilter(
                      label: 'ESTADO',
                      value: _filtroEstado,
                      items: ['todos', 'activo', 'bloqueado'],
                      onChanged: (v) => setState(() => _filtroEstado = v!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Lista de Usuarios (CP01)
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.db.collection('usuarios').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Error de conexión', style: TextStyle(color: CabifyColors.error)));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: CabifyColors.primary));

              var docs = snapshot.data!.docs;

              // CP05/06: Filtrado simultáneo
              docs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final nombre = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.toLowerCase();
                final dni = (data['dni'] ?? '').toString().toLowerCase();
                final rol = data['rol'] ?? 'pasajero';
                final estado = data['estado'] ?? 'activo';

                bool matchesQuery = nombre.contains(_queryBuscador) || dni.contains(_queryBuscador);
                bool matchesRol = _filtroRol == 'todos' || rol == _filtroRol;
                bool matchesEstado = _filtroEstado == 'todos' || estado == _filtroEstado;

                return matchesQuery && matchesRol && matchesEstado;
              }).toList();

              if (docs.isEmpty) {
                return Center(
                  child: Text('No se encontraron usuarios.', style: TextStyle(color: CabifyColors.textSecondary)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final id = docs[i].id;
                  final nombre = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}';
                  final rol = data['rol'] ?? 'pasajero';
                  final estado = data['estado'] ?? 'activo';
                  final bloqueado = estado == 'bloqueado';

                  return Card(
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: CabifyColors.border)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () => _verDetalleUsuario(context, data, id),
                      leading: CircleAvatar(
                        backgroundColor: (rol == 'conductor' ? CabifyColors.primary : Colors.blue).withValues(alpha: 0.1),
                        child: Icon(rol == 'conductor' ? Icons.drive_eta : Icons.person, 
                                   color: rol == 'conductor' ? CabifyColors.primary : Colors.blue, size: 20),
                      ),
                      title: Text(nombre, style: const TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('${rol.toUpperCase()} · ${data['celular'] ?? '-'}', 
                                    style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 12)),
                      trailing: Icon(bloqueado ? Icons.lock : Icons.check_circle, 
                                    color: bloqueado ? CabifyColors.error : CabifyColors.success, size: 18),
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

  Widget _dropdownFilter({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down, color: CabifyColors.textSecondary, size: 16),
          style: const TextStyle(color: CabifyColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
          items: items.map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // CP01: Ver detalle completo
  void _verDetalleUsuario(BuildContext context, Map<String, dynamic> data, String uid) {
    final fecha = (data['creadoEn'] as Timestamp?)?.toDate();
    final rol = data['rol'] ?? 'pasajero';
    final estado = data['estado'] ?? 'activo';
    final bloqueado = estado == 'bloqueado';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${data['nombre']} ${data['apellido']}', 
          style: const TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailItem('CELULAR', data['celular'] ?? '-'),
            _detailItem('DNI', data['dni'] ?? '-'),
            _detailItem('ROL', rol.toUpperCase()),
            _detailItem('ESTADO', estado.toUpperCase(), color: bloqueado ? CabifyColors.error : CabifyColors.success),
            _detailItem('REGISTRO', fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : '-'),
            if (bloqueado && data['motivoBloqueo'] != null)
              _detailItem('MOTIVO', data['motivoBloqueo'], color: Colors.orange),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CERRAR', style: TextStyle(color: CabifyColors.textSecondary))),
          // CP05, CP06: Botón Bloquear / Habilitar
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleBloqueo(uid, nombre: '${data['nombre']} ${data['apellido']}', esBloqueado: bloqueado);
            },
            style: ElevatedButton.styleFrom(backgroundColor: bloqueado ? CabifyColors.success : CabifyColors.error),
            child: Text(bloqueado ? 'HABILITAR' : 'BLOQUEAR', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color ?? CabifyColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // CP05, CP06 logic
  Future<void> _toggleBloqueo(String uid, {required String nombre, required bool esBloqueado}) async {
    final action = esBloqueado ? 'habilitar' : 'bloquear';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${action.toUpperCase()} USUARIO', 
          style: const TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('¿Está seguro de que desea $action a $nombre?', style: const TextStyle(color: CabifyColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: CabifyColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: esBloqueado ? CabifyColors.success : CabifyColors.error),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final Map<String, dynamic> update = {
          'estado': esBloqueado ? 'activo' : 'bloqueado',
          'bloqueado': !esBloqueado,
        };
        if (!esBloqueado) {
          update['motivoBloqueo'] = 'Acción administrativa';
          update['fechaBloqueo'] = FieldValue.serverTimestamp();
        }
        
        await widget.db.collection('usuarios').doc(uid).update(update);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Usuario ${esBloqueado ? 'habilitado' : 'bloqueado'} con éxito.'), backgroundColor: CabifyColors.success)
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: CabifyColors.error)
          );
        }
      }
    }
  }
}
