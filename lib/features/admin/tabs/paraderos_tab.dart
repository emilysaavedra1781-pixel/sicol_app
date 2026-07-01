import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app_theme.dart';

class ParaderosTab extends StatefulWidget {
  final FirebaseFirestore db;
  const ParaderosTab({super.key, required this.db});

  @override
  State<ParaderosTab> createState() => _ParaderosTabState();
}

class _ParaderosTabState extends State<ParaderosTab> {
  String _rutaSeleccionada = 'Chosica a Lima';
  final _txtNombre = TextEditingController();
  final _txtReferencia = TextEditingController();
  final _txtOrden = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _txtNombre.dispose();
    _txtReferencia.dispose();
    _txtOrden.dispose();
    super.dispose();
  }

  // CP02, CP03, CP05, CP08, CP09, CP11
  Future<void> _guardarParadero({String? docId, List<DocumentSnapshot>? currentList}) async {
    final nombre = _txtNombre.text.trim();
    final referencia = _txtReferencia.text.trim();
    final nuevoOrden = int.tryParse(_txtOrden.text.trim());

    // CP08: Validación de campos incompletos
    if (nombre.isEmpty || referencia.isEmpty || nuevoOrden == null) {
      String faltantes = "";
      if (nombre.isEmpty) faltantes += "Nombre, ";
      if (referencia.isEmpty) faltantes += "Referencia, ";
      if (nuevoOrden == null) faltantes += "Orden";
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Faltan campos: ${faltantes.replaceAll(RegExp(r", $"), "")}'), backgroundColor: CabifyColors.error),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (docId == null) {
        // EA01: Validar duplicidad de nombre en la misma ruta
        final duplicado = await widget.db
            .collection('paraderos')
            .where('rutaId', isEqualTo: _rutaSeleccionada)
            .where('nombre', isEqualTo: nombre)
            .get();

        if (duplicado.docs.isNotEmpty) {
          _mostrarError('El paradero "$nombre" ya existe en esta ruta.');
          setState(() => _isProcessing = false);
          return;
        }

        // CP09: Manejo de orden duplicado al agregar
        await _ajustarOrdenesYGuardar(null, nuevoOrden, nombre, referencia, currentList ?? []);
      } else {
        // CP03, CP05: Editar y Reordenar por número
        await _ajustarOrdenesYGuardar(docId, nuevoOrden, nombre, referencia, currentList ?? []);
      }

      _txtNombre.clear(); _txtReferencia.clear(); _txtOrden.clear();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // CP11: Error de conexión
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al guardar: $e'), backgroundColor: CabifyColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // CP05, CP09 logic: Ajusta automáticamente los órdenes para evitar duplicados
  Future<void> _ajustarOrdenesYGuardar(String? docId, int nuevoOrden, String nombre, String referencia, List<DocumentSnapshot> currentList) async {
    final batch = widget.db.batch();
    
    // Convertimos a lista mutable de objetos locales para manipular
    List<Map<String, dynamic>> items = currentList.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {'id': doc.id, 'orden': data['orden'] ?? 0, 'nombre': data['nombre']};
    }).toList();

    if (docId == null) {
      // Agregar nuevo
      items.add({'id': 'new', 'orden': nuevoOrden, 'nombre': nombre, 'isNew': true});
    } else {
      // Actualizar existente
      final idx = items.indexWhere((it) => it['id'] == docId);
      if (idx != -1) {
        items[idx]['orden'] = nuevoOrden;
        items[idx]['nombre'] = nombre;
        items[idx]['updateMain'] = true;
      }
    }

    // Ordenar por el nuevo valor de 'orden' propuesto, luego por nombre
    items.sort((a, b) {
      int cmp = (a['orden'] as int).compareTo(b['orden'] as int);
      if (cmp != 0) return cmp;
      return (a['nombre'] as String).compareTo(b['nombre'] as String);
    });

    // Reasignar órdenes secuenciales 1, 2, 3...
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final realId = item['id'];
      final assignedOrder = i + 1;

      if (realId == 'new') {
        final newRef = widget.db.collection('paraderos').doc();
        batch.set(newRef, {
          'nombre': nombre,
          'referencia': referencia,
          'orden': assignedOrder,
          'rutaId': _rutaSeleccionada,
          'activo': true,
        });
      } else {
        final ref = widget.db.collection('paraderos').doc(realId);
        if (item['updateMain'] == true) {
          batch.update(ref, {
            'nombre': nombre,
            'referencia': referencia,
            'orden': assignedOrder,
          });
        } else {
          batch.update(ref, {'orden': assignedOrder});
        }
      }
    }

    await batch.commit();
  }

  // CP04: Reordenar arrastrando
  Future<void> _handleReorder(int oldIndex, int newIndex, List<DocumentSnapshot> list) async {
    if (newIndex > oldIndex) newIndex -= 1;
    
    final batch = widget.db.batch();
    final items = list.toList();
    final movedItem = items.removeAt(oldIndex);
    items.insert(newIndex, movedItem);

    for (int i = 0; i < items.length; i++) {
      batch.update(items[i].reference, {'orden': i + 1});
    }

    try {
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al reordenar: $e'), backgroundColor: CabifyColors.error),
        );
      }
    }
  }

  void _mostrarError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registro Denegado'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ENTENDIDO'))],
      ),
    );
  }

  // CP06, CP07
  Future<void> _toggleEstadoParadero(String id, bool actual, int activosCount) async {
    if (actual == true && activosCount <= 1) {
      _mostrarError('Debe haber al menos un paradero activo por ruta.');
      return;
    }
    await widget.db.collection('paraderos').doc(id).update({'activo': !actual});
  }

  void _abrirFormulario({String? docId, String? nom, String? ref, int? ord, List<DocumentSnapshot>? currentList}) {
    if (docId != null) {
      _txtNombre.text = nom ?? '';
      _txtReferencia.text = ref ?? '';
      _txtOrden.text = ord?.toString() ?? '1';
    } else {
      _txtNombre.clear(); _txtReferencia.clear(); 
      _txtOrden.text = ((currentList?.length ?? 0) + 1).toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(docId == null ? 'Nuevo Paradero' : 'Editar Paradero', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            TextField(controller: _txtNombre, decoration: const InputDecoration(labelText: 'Nombre del paradero')),
            const SizedBox(height: 16),
            TextField(controller: _txtReferencia, decoration: const InputDecoration(labelText: 'Referencia visual')),
            const SizedBox(height: 16),
            TextField(controller: _txtOrden, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'N° de Orden (Posición)')),
            const SizedBox(height: 32),
            _isProcessing 
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(onPressed: () => _guardarParadero(docId: docId, currentList: currentList), child: const Text('GUARDAR PARADERO')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // CP01: Selector de ruta
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _routeBtn('Chosica a Lima', 'Chosica → Lima'),
              const SizedBox(width: 12),
              _routeBtn('Lima a Chosica', 'Lima → Chosica'),
            ],
          ),
        ),
        // CP01: Lista de paraderos en tiempo real
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.db.collection('paraderos').where('rutaId', isEqualTo: _rutaSeleccionada).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs;
              final activosCount = docs.where((doc) => (doc.data() as Map)['activo'] == true).length;
              
              // Ordenar por campo 'orden'
              final lista = docs.toList()..sort((a, b) => ((a.data() as Map)['orden'] ?? 99).compareTo((b.data() as Map)['orden'] ?? 99));

              // CP10: Ruta sin paraderos
              if (lista.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off_outlined, color: Colors.grey[300], size: 64),
                        const SizedBox(height: 16),
                        const Text('Esta ruta no tiene paraderos registrados. Agrega el primero.', 
                          textAlign: TextAlign.center, style: TextStyle(color: CabifyColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }

              return ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                onReorder: (oldIndex, newIndex) => _handleReorder(oldIndex, newIndex, lista),
                itemBuilder: (context, i) {
                  final d = lista[i].data() as Map<String, dynamic>;
                  final activo = d['activo'] ?? true;
                  final docId = lista[i].id;

                  return Card(
                    key: ValueKey(docId),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: CabifyColors.border)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: activo ? CabifyColors.primary.withValues(alpha: 0.1) : Colors.grey[100],
                        child: Text('${d['orden'] ?? i + 1}', style: TextStyle(color: activo ? CabifyColors.primary : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      title: Text(d['nombre'] ?? '-', style: TextStyle(fontWeight: FontWeight.bold, decoration: activo ? null : TextDecoration.lineThrough, color: activo ? CabifyColors.textPrimary : Colors.grey)),
                      subtitle: Text('Ref: ${d['referencia']}', style: const TextStyle(fontSize: 12, color: CabifyColors.textSecondary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, size: 20, color: CabifyColors.primary), onPressed: () => _abrirFormulario(docId: docId, nom: d['nombre'], ref: d['referencia'], ord: d['orden'], currentList: lista)),
                          // CP06, CP07: Activar/Desactivar
                          IconButton(icon: Icon(activo ? Icons.visibility : Icons.visibility_off, color: activo ? CabifyColors.success : CabifyColors.error), 
                                     onPressed: () => _toggleEstadoParadero(docId, activo, activosCount)),
                          const Icon(Icons.drag_indicator, color: Colors.grey, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: CabifyColors.border))),
          child: ElevatedButton.icon(
            onPressed: () => _abrirFormulario(), 
            icon: const Icon(Icons.add, color: Colors.white), 
            label: const Text('AGREGAR PARADERO'),
            style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.primary, foregroundColor: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _routeBtn(String val, String label) {
    final sel = _rutaSeleccionada == val;
    return GestureDetector(
      onTap: () => setState(() => _rutaSeleccionada = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? CabifyColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? CabifyColors.primary : CabifyColors.border),
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : CabifyColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
