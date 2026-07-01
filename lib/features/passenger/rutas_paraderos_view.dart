import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_theme.dart';

class RutasParaderosView extends StatefulWidget {
  const RutasParaderosView({super.key});

  @override
  State<RutasParaderosView> createState() => _RutasParaderosViewState();
}

class _RutasParaderosViewState extends State<RutasParaderosView> {
  String _rutaSeleccionada = 'Chosica a Lima';
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CabifyColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Rutas y Paraderos', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Selector de Ruta (CP01)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRouteBtn('Chosica a Lima', 'Ruta 1\nChosica → Lima'),
                const SizedBox(width: 16),
                _buildRouteBtn('Lima a Chosica', 'Ruta 2\nLima → Chosica'),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // CP03: Los paraderos vienen de Firestore en tiempo real. 
              // Firestore maneja caché interno para "Sin conexión" (CP03).
              stream: _db.collection('paraderos')
                  .where('rutaId', isEqualTo: _rutaSeleccionada)
                  .where('activo', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: CabifyColors.error, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Sin conexión a internet. Verifica tu conexión e inténtalo de nuevo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: CabifyColors.textSecondary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text('REINTENTAR'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final paraderos = snapshot.data!.docs.toList()
                  ..sort((a, b) => ((a.data() as Map)['orden'] ?? 0).compareTo((b.data() as Map)['orden'] ?? 0));

                if (paraderos.isEmpty) {
                  return const Center(child: Text('No hay paraderos registrados para esta ruta.'));
                }

                return InteractiveViewer(
                  // CP02: Soporte para gesto pinch-to-zoom y desplazamiento.
                  boundaryMargin: const EdgeInsets.all(100),
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                      child: Column(
                        children: List.generate(paraderos.length, (index) {
                          final data = paraderos[index].data() as Map<String, dynamic>;
                          final isLast = index == paraderos.length - 1;

                          return Column(
                            children: [
                              _buildParaderoNode(
                                index + 1,
                                data['nombre'] ?? '-',
                                data['referencia'] ?? '-',
                              ),
                              if (!isLast)
                                Container(
                                  width: 4,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: CabifyColors.primary.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteBtn(String val, String label) {
    final sel = _rutaSeleccionada == val;
    return GestureDetector(
      onTap: () => setState(() => _rutaSeleccionada = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: sel ? CabifyColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? CabifyColors.primary : CabifyColors.border, width: 2),
          boxShadow: sel ? [BoxShadow(color: CabifyColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: sel ? Colors.white : CabifyColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildParaderoNode(int orden, String nombre, String referencia) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: CabifyColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: CabifyColors.primary, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$orden',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CabifyColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ref: $referencia',
                  style: const TextStyle(fontSize: 11, color: CabifyColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
