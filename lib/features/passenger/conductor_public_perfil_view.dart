import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_theme.dart';

class ConductorPublicPerfilView extends StatelessWidget {
  final String conductorUid;

  const ConductorPublicPerfilView({super.key, required this.conductorUid});

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
        title: const Text('Perfil del Conductor', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('usuarios').doc(conductorUid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Conductor no encontrado'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final vehiculo = data['vehiculo'] as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Foto de perfil
                CircleAvatar(
                  radius: 60,
                  backgroundColor: CabifyColors.primary.withValues(alpha: 0.1),
                  backgroundImage: data['fotoUrl'] != null ? NetworkImage(data['fotoUrl']) : null,
                  child: data['fotoUrl'] == null 
                      ? Text(
                          _getInitials(data['nombre'], data['apellido']),
                          style: const TextStyle(fontSize: 40, color: CabifyColors.primary, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                // Nombre completo
                Text(
                  '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}',
                  style: Theme.of(context).textTheme.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Número de licencia
                _badge('Licencia: ${data['numeroLicencia'] ?? '-'}'),
                
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),
                
                // Datos del vehículo
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('VEHÍCULO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CabifyColors.textSecondary, letterSpacing: 1)),
                ),
                const SizedBox(height: 16),
                
                // Foto del vehículo
                if (vehiculo['fotoVehiculoUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      vehiculo['fotoVehiculoUrl'],
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: CabifyColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CabifyColors.border),
                    ),
                    child: const Icon(Icons.directions_car, size: 48, color: CabifyColors.textSecondary),
                  ),
                
                const SizedBox(height: 24),
                
                _buildVehicleDetail('Placa', vehiculo['placa'] ?? '-'),
                _buildVehicleDetail('Marca y modelo', '${vehiculo['marca'] ?? ''} ${vehiculo['modelo'] ?? ''}'),
                _buildVehicleDetail('Color', vehiculo['color'] ?? '-'),
                _buildVehicleDetail('Capacidad', '${vehiculo['capacidad'] ?? '-'} asientos'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CabifyColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: CabifyColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildVehicleDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CabifyColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: CabifyColors.textPrimary)),
        ],
      ),
    );
  }

  String _getInitials(String? nombre, String? apellido) {
    String n = (nombre != null && nombre.isNotEmpty) ? nombre[0].toUpperCase() : '';
    String a = (apellido != null && apellido.isNotEmpty) ? apellido[0].toUpperCase() : '';
    return '$n$a';
  }
}
