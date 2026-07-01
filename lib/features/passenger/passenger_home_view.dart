import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/booking_service.dart';
import 'buscar_tab.dart';
import 'reservas_tab.dart';
import 'perfil_tab.dart';
import 'reservas_historial_view.dart';
import '../shared/reportar_incidencia_view.dart';
import '../shared/mis_incidencias_view.dart';
import '../../widgets/logout_helper.dart';

class PassengerHomeView extends StatefulWidget {
  const PassengerHomeView({super.key});

  @override
  State<PassengerHomeView> createState() => _PassengerHomeViewState();
}

class _PassengerHomeViewState extends State<PassengerHomeView> {
  final _auth = FirebaseAuth.instance;
  final _bookingService = BookingService();

  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        final uid = snapshot.data?.uid ?? '';

        if (uid.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        return Scaffold(
          appBar: _tabIndex != 0 ? null : AppBar(
            title: const Text('SICOL'),
          ),
          drawer: Drawer(
            child: Column(
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: Theme.of(context).primaryColor),
                  child: const Center(child: Text('MENÚ PASAJERO', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('MI HISTORIAL'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ReservasHistorialView(uid: uid)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.report_problem),
                  title: const Text('REPORTAR PROBLEMA'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportarIncidenciaView(rolUsuario: 'pasajero', viajeId: 'GENERAL')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.list_alt),
                  title: const Text('MIS INCIDENCIAS'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MisIncidenciasView()));
                  },
                ),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('CERRAR SESIÓN'),
                  onTap: () => LogoutHelper.showLogoutDialog(context),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          body: IndexedStack(
            index: _tabIndex,
            children: [
              const BuscarTab(),
              ReservasTab(uid: uid, bookingService: _bookingService),
              PerfilTab(uid: uid),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _tabIndex,
            onTap: (i) => setState(() => _tabIndex = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Viajar'),
              BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_rounded), label: 'Mis Viajes'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }
}
