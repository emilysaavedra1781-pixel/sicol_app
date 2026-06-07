import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/theme/app_colors.dart';
import 'services/auth_service.dart';
import 'features/auth/login/login_view.dart';
import 'features/passenger/passenger_home_view.dart';

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
      // AuthGate decide si mostrar login o home según el estado de Firebase
      home: const AuthGate(),
    );
  }
}

/// Escucha el estado de autenticación de Firebase.
/// - Si hay sesión activa → PassengerHomeView
/// - Si no hay sesión → LoginView
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0E1A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1E6BFF)),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Verificar si el usuario existe en Firestore
          return FutureBuilder(
            future: FirebaseFirestore.instance
                .collection('usuarios')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, firestoreSnapshot) {
              if (firestoreSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF0A0E1A),
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E6BFF)),
                  ),
                );
              }

              // Si no existe en Firestore, cerrar sesión
              if (!firestoreSnapshot.hasData || !firestoreSnapshot.data!.exists) {
                FirebaseAuth.instance.signOut();
                return const LoginView();
              }

              return const PassengerHomeView();
            },
          );
        }

        return const LoginView();
      },
    );
  }
}