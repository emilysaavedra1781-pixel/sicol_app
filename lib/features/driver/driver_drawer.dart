import 'package:flutter/material.dart';
import 'driver_home_view.dart';
import 'driver_ingresos_view.dart';
import 'driver_historial_viajes_view.dart';
import '../shared/reportar_incidencia_view.dart';
import '../shared/mis_incidencias_view.dart';

/// Menú lateral fijo del conductor — acceso siempre disponible
/// a Home, Mis viajes (historial) y Mis ingresos.
class DriverDrawer extends StatelessWidget {
  /// Ruta actual para resaltar el ítem activo: 'home' | 'viajes' | 'ingresos'
  final String currentRoute;

  const DriverDrawer({super.key, required this.currentRoute});

  void _ir(BuildContext context, String route, Widget destino) {
    Navigator.pop(context); // cierra el drawer
    if (route == currentRoute) return; // ya está en esa pantalla
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destino),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF111827),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E6BFF), Color(0xFF0A4BCC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.drive_eta_rounded, color: Colors.white, size: 32),
                  SizedBox(height: 10),
                  Text('SICOL — Conductor',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _item(
              context,
              icon: Icons.home_outlined,
              label: 'Inicio',
              route: 'home',
              onTap: () =>
                  _ir(context, 'home', const DriverHomeView()),
            ),
            _item(
              context,
              icon: Icons.route_outlined,
              label: 'Mis viajes',
              route: 'viajes',
              onTap: () => _ir(
                  context, 'viajes', const DriverHistorialViajesView()),
            ),
            _item(
              context,
              icon: Icons.payments_outlined,
              label: 'Mis ingresos',
              route: 'ingresos',
              onTap: () =>
                  _ir(context, 'ingresos', const DriverIngresosView()),
            ),
            _item(
              context,
              icon: Icons.report_problem_outlined,
              label: 'Reportar incidencia',
              route: 'incidencia',
              onTap: () {
                Navigator.pop(context); // cierra el drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportarIncidenciaView(
                      rolUsuario: 'conductor',
                    ),
                  ),
                );
              },
            ),
            _item(
              context,
              icon: Icons.history_rounded,
              label: 'Mis incidencias',
              route: 'mis_incidencias',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MisIncidenciasView(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String route,
        required VoidCallback onTap,
      }) {
    final activo = route == currentRoute;
    final color = activo ? const Color(0xFF1E6BFF) : const Color(0xFF9CA3AF);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: activo ? const Color(0xFF1E6BFF).withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(label,
            style: TextStyle(
                color: activo ? Colors.white : const Color(0xFFD1D5DB),
                fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }
}