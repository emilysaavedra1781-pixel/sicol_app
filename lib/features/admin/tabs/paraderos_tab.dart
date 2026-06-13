import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void dispose() {
    _txtNombre.dispose();
    _txtReferencia.dispose();
    _txtOrden.dispose();
    super.dispose();
  }

  Future<void> _guardarParadero({String? docId}) async {
    final nombre = _txtNombre.text.trim();
    final referencia = _txtReferencia.text.trim();
    final orden = int.tryParse(_txtOrden.text.trim()) ?? 1;

    if (nombre.isEmpty || referencia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Complete todos los campos requeridos.')),
      );
      return;
    }

    if (docId == null) {
      // EXCEPCIÓN EA01: Validar duplicidad de nombre en la misma ruta
      final duplicado = await widget.db
          .collection('paraderos')
          .where('rutaId', isEqualTo: _rutaSeleccionada)
          .where('nombre', isEqualTo: nombre)
          .get();

      if (duplicado.docs.isNotEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF111827),
            title: const Text('Registro Denegado (EA01)',
                style: TextStyle(color: Colors.white)),
            content: Text(
              'El paradero "$nombre" ya existe mapeado en la ruta $_rutaSeleccionada.',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
        return;
      }

      await widget.db.collection('paraderos').add({
        'nombre': nombre,
        'referencia': referencia,
        'orden': orden,
        'rutaId': _rutaSeleccionada,
        'activo': true,
      });
    } else {
      await widget.db.collection('paraderos').doc(docId).update({
        'nombre': nombre,
        'referencia': referencia,
        'orden': orden,
      });
    }

    _txtNombre.clear();
    _txtReferencia.clear();
    _txtOrden.clear();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleEstadoParadero(String id, bool actual, int activosCount) async {
    // EXCEPCIÓN EA02: No permitir deshabilitar el último paradero activo
    if (actual == true && activosCount <= 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: const Text('Acción Bloqueada (EA02)',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'Cada ruta fija debe contar con al menos un paradero activo en todo momento para los pasajeros.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
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
      _txtNombre.clear();
      _txtReferencia.clear();
      _txtOrden.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              docId == null ? 'Nuevo Paradero en Ruta' : 'Modificar Paradero',
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _txtNombre,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nombre del punto (ej: Ovalo Santa Anita)',
                labelStyle: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            TextField(
              controller: _txtReferencia,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Referencia visual',
                labelStyle: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            TextField(
              controller: _txtOrden,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'N° de Posición de Secuencia (Orden)',
                labelStyle: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _guardarParadero(docId: docId),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6BFF)),
                child: const Text('Guardar Paradero Fijo'),
              ),
            ),
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
              ChoiceChip(
                label: const Text('Chosica → Lima'),
                selected: _rutaSeleccionada == 'Chosica a Lima',
                onSelected: (_) => setState(() => _rutaSeleccionada = 'Chosica a Lima'),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Lima → Chosica'),
                selected: _rutaSeleccionada == 'Lima a Chosica',
                onSelected: (_) => setState(() => _rutaSeleccionada = 'Lima a Chosica'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.db
                .collection('paraderos')
                .where('rutaId', isEqualTo: _rutaSeleccionada)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              final activosCount = docs
                  .where((doc) =>
              (doc.data() as Map<String, dynamic>)['activo'] == true)
                  .length;

              final listaOrdenada = docs.toList()
                ..sort((a, b) {
                  final ordA = (a.data() as Map<String, dynamic>)['orden'] ?? 99;
                  final ordB = (b.data() as Map<String, dynamic>)['orden'] ?? 99;
                  return ordA.compareTo(ordB);
                });

              if (listaOrdenada.isEmpty) {
                return const Center(
                  child: Text('Ningún paradero registrado en este tramo.',
                      style: TextStyle(color: Color(0xFF6B7280))),
                );
              }

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
                      border: Border.all(
                        color: activo
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFFF3B30).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: activo
                              ? const Color(0xFF1E6BFF).withOpacity(0.2)
                              : const Color(0xFF374151),
                          radius: 16,
                          child: Text(
                            '${d['orden'] ?? i}',
                            style: TextStyle(
                              color: activo ? const Color(0xFF1E6BFF) : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d['nombre'] ?? '-',
                                style: TextStyle(
                                  color: activo ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                  decoration: activo
                                      ? TextDecoration.none
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                              Text(
                                'Ref: ${d['referencia'] ?? '-'}',
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Color(0xFF6B7280), size: 18),
                          onPressed: () => _abrirFormulario(
                            docId: doc.id,
                            nom: d['nombre'],
                            ref: d['referencia'],
                            ord: d['orden'],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            activo ? Icons.visibility : Icons.visibility_off,
                            color: activo
                                ? const Color(0xFF10B981)
                                : const Color(0xFFFF3B30),
                          ),
                          onPressed: () =>
                              _toggleEstadoParadero(doc.id, activo, activosCount),
                        ),
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
          child: ElevatedButton.icon(
            onPressed: () => _abrirFormulario(),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6BFF)),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Nuevo Paradero Fijo'),
          ),
        ),
      ],
    );
  }
}