import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/booking_service.dart';
import 'buscar_tab.dart';
import 'reservas_tab.dart';
import 'perfil_tab.dart';

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

        if (uid.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0E1A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1E6BFF)),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
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
            backgroundColor: const Color(0xFF111827),
            selectedItemColor: const Color(0xFF1E6BFF),
            unselectedItemColor: const Color(0xFF6B7280),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded), label: 'Buscar'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.confirmation_number_rounded), label: 'Mis Reservas'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded), label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }
}