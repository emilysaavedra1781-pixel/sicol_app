import 'package:flutter/material.dart';
import 'driver_home_view.dart';
import 'driver_ingresos_view.dart';
import 'driver_historial_viajes_view.dart';
import 'driver_perfil_view.dart';
import '../shared/reportar_incidencia_view.dart';
import '../shared/mis_incidencias_view.dart';
import '../../services/trip_service.dart';
import '../../widgets/logout_helper.dart';

class DriverDrawer extends StatelessWidget {
  final String currentRoute;

  const DriverDrawer({super.key, required this.currentRoute});

  void _ir(BuildContext context, String route, Widget destino) {
    Navigator.pop(context);
    if (route == currentRoute) return;
    
    // Si estamos navegando desde el Home, usamos push para permitir volver con el botón atrás.
    // Si ya estamos en una sub-pantalla, reemplazamos para no acumular stack.
    if (currentRoute == 'home') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destino),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destino),
      );
    }
  }

  Future<void> _abrirReportarIncidencia(BuildContext context) async {
    final tripService = TripService();
    final viajeActivo = await tripService.getViajeActivo();
    
    if (!context.mounted) return;
    Navigator.pop(context);

    if (viajeActivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta función solo está disponible durante un viaje en curso.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportarIncidenciaView(
          rolUsuario: 'conductor',
          viajeId: viajeActivo.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.drive_eta, color: Colors.white, size: 30),
                  ),
                  SizedBox(height: 16),
                  Text('CONDUCTOR',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _item(context, icon: Icons.home_rounded, label: 'INICIO', route: 'home', 
                onTap: () => _ir(context, 'home', const DriverHomeView())),
            _item(context, icon: Icons.route_rounded, label: 'MIS VIAJES', route: 'viajes', 
                onTap: () => _ir(context, 'viajes', const DriverHistorialViajesView())),
            _item(context, icon: Icons.payments_rounded, label: 'MIS INGRESOS', route: 'ingresos', 
                onTap: () => _ir(context, 'ingresos', const DriverIngresosView())),
            _item(context, icon: Icons.person_rounded, label: 'MI PERFIL', route: 'perfil', 
                onTap: () => _ir(context, 'perfil', const DriverPerfilView())),
            const Divider(indent: 20, endIndent: 20, height: 32),
            _item(context, icon: Icons.report_problem_outlined, label: 'REPORTAR INCIDENCIA', route: 'incidencia', 
                onTap: () => _abrirReportarIncidencia(context)),
            _item(context, icon: Icons.history_rounded, label: 'MIS INCIDENCIAS', route: 'mis_incidencias', 
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MisIncidenciasView()));
                }),
            const Spacer(),
            _item(context, icon: Icons.logout_rounded, label: 'CERRAR SESIÓN', route: 'logout', 
                onTap: () => LogoutHelper.showLogoutDialog(context)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, {required IconData icon, required String label, required String route, required VoidCallback onTap}) {
    final activo = route == currentRoute;
    final primary = Theme.of(context).primaryColor;

    return ListTile(
      leading: Icon(icon, color: activo ? primary : const Color(0xFF6B7280)),
      title: Text(label,
          style: TextStyle(
              color: activo ? primary : const Color(0xFF111827),
              fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5)),
      onTap: onTap,
    );
  }
}
