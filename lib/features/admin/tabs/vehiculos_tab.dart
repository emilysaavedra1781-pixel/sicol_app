import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app_theme.dart';

class VehiculosTab extends StatefulWidget {
  final FirebaseFirestore db;
  const VehiculosTab({super.key, required this.db});

  @override
  State<VehiculosTab> createState() => _VehiculosTabState();
}

class _VehiculosTabState extends State<VehiculosTab> {
  final _formKey = GlobalKey<FormState>();
  final _placaCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _placaCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _capacidadCtrl.dispose();
    super.dispose();
  }

  // CP02, CP05: Validar placa duplicada y registrar
  Future<void> _registrarVehiculo({String? docId, Map<String, dynamic>? initialData}) async {
    final placa = _placaCtrl.text.trim().toUpperCase();
    
    setState(() => _loading = true);

    try {
      // Validar duplicidad (excluyendo el actual si es edición)
      final query = await widget.db
          .collection('vehiculos')
          .where('placa', isEqualTo: placa)
          .get();

      if (query.docs.isNotEmpty && (docId == null || query.docs.first.id != docId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Esta placa ya está registrada en el sistema.'), backgroundColor: CabifyColors.error)
          );
        }
        setState(() => _loading = false);
        return;
      }

      final data = {
        'placa': placa,
        'marca': _marcaCtrl.text.trim(),
        'modelo': _modeloCtrl.text.trim(),
        'anio': int.tryParse(_anioCtrl.text.trim()) ?? 0,
        'capacidad': int.tryParse(_capacidadCtrl.text.trim()) ?? 4,
        'activo': initialData?['activo'] ?? true,
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      };

      if (docId == null) {
        await widget.db.collection('vehiculos').add(data);
      } else {
        final docRef = widget.db.collection('vehiculos').doc(docId);
        final docSnap = await docRef.get();
        if (!docSnap.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Este vehículo no existe o no está disponible.'), backgroundColor: CabifyColors.error)
            );
            Navigator.pop(context);
          }
          return;
        }
        await docRef.update(data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: CabifyColors.error)
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // CP04: Desactivar vehículo
  Future<void> _desactivarVehiculo(String id, bool actual) async {
    try {
      await widget.db.collection('vehiculos').doc(id).update({'activo': !actual});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: CabifyColors.error)
        );
      }
    }
  }

  void _showForm({String? docId, Map<String, dynamic>? data}) {
    if (docId != null && data != null) {
      _placaCtrl.text = data['placa'] ?? '';
      _marcaCtrl.text = data['marca'] ?? '';
      _modeloCtrl.text = data['modelo'] ?? '';
      _anioCtrl.text = (data['anio'] ?? '').toString();
      _capacidadCtrl.text = (data['capacidad'] ?? '').toString();
    } else {
      _placaCtrl.clear(); _marcaCtrl.clear(); _modeloCtrl.clear(); _anioCtrl.clear(); _capacidadCtrl.clear();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(docId == null ? 'Registrar Vehículo' : 'Editar Vehículo', 
          style: const TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(_placaCtrl, 'Placa', 'ABC-123'),
                const SizedBox(height: 12),
                _buildField(_marcaCtrl, 'Marca', 'Toyota'),
                const SizedBox(height: 12),
                _buildField(_modeloCtrl, 'Modelo', 'Corolla'),
                const SizedBox(height: 12),
                _buildField(_anioCtrl, 'Año', '2022', TextInputType.number),
                const SizedBox(height: 12),
                _buildField(_capacidadCtrl, 'Capacidad Asientos', '4', TextInputType.number),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR', style: TextStyle(color: CabifyColors.textSecondary))),
          ElevatedButton(
            onPressed: _loading ? null : () {
              if (_formKey.currentState!.validate()) {
                _registrarVehiculo(docId: docId, initialData: data);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.primary),
            child: _loading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(docId == null ? 'REGISTRAR' : 'GUARDAR', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, String hint, [TextInputType type = TextInputType.text]) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: CabifyColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: CabifyColors.textSecondary),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: CabifyColors.border)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: CabifyColors.primary, width: 2)),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: widget.db.collection('vehiculos').orderBy('ultimaActualizacion', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error de conexión', style: TextStyle(color: CabifyColors.error)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: CabifyColors.primary));

          final docs = snapshot.data!.docs;

          // CP07: Lista vacía
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_filled_outlined, color: Colors.grey[300], size: 64),
                  const SizedBox(height: 16),
                  const Text('No hay vehículos registrados. Agrega el primero.', style: TextStyle(color: CabifyColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              final activo = d['activo'] ?? true;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CabifyColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: activo ? CabifyColors.success.withValues(alpha: 0.1) : CabifyColors.error.withValues(alpha: 0.1),
                    child: Icon(Icons.directions_car, color: activo ? CabifyColors.success : CabifyColors.error),
                  ),
                  title: Text(d['placa'] ?? '-', style: const TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
                  subtitle: Text('${d['marca']} ${d['modelo']} (${d['anio']}) · ${d['capacidad']} asientos', 
                    style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: CabifyColors.primary, size: 20),
                        onPressed: () => _showForm(docId: id, data: d),
                      ),
                      Switch(
                        value: activo,
                        activeColor: CabifyColors.success,
                        onChanged: (v) => _desactivarVehiculo(id, activo),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: CabifyColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
