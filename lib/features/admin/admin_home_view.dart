import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../widgets/logout_helper.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/conductores_tab.dart';
import 'tabs/usuarios_tab.dart';
import 'tabs/viajes_tab.dart';
import 'tabs/paraderos_tab.dart';
import 'tabs/incidencias_tab.dart';
import 'tabs/ocupacion_tab.dart';
import 'tabs/monitoreo_tab.dart';
import 'tabs/vehiculos_tab.dart';
import '../../app_theme.dart';

class AdminHomeView extends StatefulWidget {
  const AdminHomeView({super.key});

  @override
  State<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<AdminHomeView> {
  final _authService = AuthService();
  final _bookingService = BookingService();
  final _db = FirebaseFirestore.instance;
  int _tabIndex = 0;

  Future<void> _logout() async {
    await LogoutHelper.showLogoutDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ADMINISTRACIÓN',
          style: TextStyle(color: CabifyColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: CabifyColors.primary),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFF3F4F6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tab(0, Icons.dashboard_rounded, 'DASHBOARD'),
                  _tab(1, Icons.drive_eta_rounded, 'CONDUCTORES'),
                  _tab(2, Icons.directions_car_filled_rounded, 'VEHÍCULOS'),
                  _tab(3, Icons.people_rounded, 'USUARIOS'),
                  _tab(4, Icons.map_rounded, 'CONTROL VIAJES'),
                  _tab(5, Icons.gps_fixed_rounded, 'MONITOREO'),
                  _tab(6, Icons.event_seat_rounded, 'OCUPACIÓN'),
                  _tab(7, Icons.add_location_alt_rounded, 'PARADEROS'),
                  _tab(8, Icons.report_problem_outlined, 'INCIDENCIAS'),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                DashboardTab(db: _db),
                ConductoresTab(
                  authService: _authService,
                  db: _db,
                  onAprobar: (uid, n) => _aprobarConductor(uid, n),
                  onRechazar: (uid, n) => _rechazarConductor(uid, n),
                ),
                VehiculosTab(db: _db),
                UsuariosTab(db: _db, onToggle: (u, n, b) => {}),
                ViajesTab(db: _db, bookingService: _bookingService),
                MonitoreoTab(db: _db),
                OcupacionTab(db: _db),
                ParaderosTab(db: _db),
                IncidenciasTab(db: _db),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _aprobarConductor(String uid, String nombre) async {
    await _authService.aprobarConductor(uid);
  }

  Future<void> _rechazarConductor(String uid, String nombre) async {
    await _authService.rechazarConductor(uid);
  }

  Widget _tab(int index, IconData icon, String label) {
    final active = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? CabifyColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: active ? CabifyColors.primary : CabifyColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? CabifyColors.textPrimary : CabifyColors.textSecondary,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
