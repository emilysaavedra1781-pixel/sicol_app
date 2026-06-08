import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/login/login_view.dart';
import 'features/passenger/passenger_home_view.dart';
import 'features/driver/driver_pending_view.dart';
import 'features/driver/driver_home_view.dart';
import 'features/admin/admin_home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SICOL',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginView();
        }

        final uid = snapshot.data!.uid;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .get(),
          builder: (context, firestoreSnap) {
            if (firestoreSnap.connectionState == ConnectionState.waiting) {
              return _loading();
            }

            if (!firestoreSnap.hasData || !firestoreSnap.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const LoginView();
            }

            final data =
            firestoreSnap.data!.data() as Map<String, dynamic>;
            final rol = data['rol'] ?? '';
            final estado = data['estado'] ?? '';

            switch (rol) {
              case 'pasajero':
                return const PassengerHomeView();
              case 'conductor':
                if (estado == 'activo') return const DriverHomeView();
                if (estado == 'rechazado') {
                  FirebaseAuth.instance.signOut();
                  return const LoginView();
                }
                return const DriverPendingView();
              case 'admin':
                return const AdminHomeView();
              default:
                FirebaseAuth.instance.signOut();
                return const LoginView();
            }
          },
        );
      },
    );
  }

  Widget _loading() => const Scaffold(
    backgroundColor: Color(0xFF0A0E1A),
    body: Center(
      child: CircularProgressIndicator(color: Color(0xFF1E6BFF)),
    ),
  );
}