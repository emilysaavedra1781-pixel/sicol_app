import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';
import 'features/passenger/payment_result_view.dart';
import 'app_theme.dart';
import 'features/auth/login/login_view.dart';
import 'features/passenger/passenger_home_view.dart';
import 'features/driver/driver_pending_view.dart';
import 'features/driver/driver_home_view.dart';
import 'features/admin/admin_home_view.dart';

/// Clave global de navegación — permite mostrar SnackBars/diálogos y
/// navegar desde fuera del árbol de widgets (por ejemplo, al recibir
/// una notificación push en foreground). RF30/RF42.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Agrega esto:
  await FirebaseAuth.instance.setSettings(
    appVerificationDisabledForTesting: true,
    forceRecaptchaFlow: false,
  );

  // RF30/RF42 — Parte 3: empezar a escuchar notificaciones push
  // (foreground + tap en background/terminated).
  NotificationService().escucharNotificaciones(navigatorKey);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    _deepLinkService.onPaymentResult = _handlePaymentResult;
    _deepLinkService.init();
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  void _handlePaymentResult(String status) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    String cleanStatus;
    switch (status) {
      case 'payment-success': cleanStatus = 'success'; break;
      case 'payment-error': cleanStatus = 'error'; break;
      case 'payment-pending': cleanStatus = 'pending'; break;
      default: return;
    }

    final purchaseData = DeepLinkService().lastPurchaseContext;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentResultView(
          status: cleanStatus,
          viajeId: purchaseData?['viajeId'],
          paradero: purchaseData?['paradero'],
          nombrePasajero: purchaseData?['nombrePasajero'],
          rutaSeleccionada: purchaseData?['rutaSeleccionada'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'SICOL',
      theme: CabifyTheme.lightTheme,
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

            // Si no existe en usuarios, buscamos en admins
            if (!firestoreSnap.hasData || !firestoreSnap.data!.exists) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('admins').doc(uid).get(),
                builder: (context, adminSnap) {
                  if (adminSnap.connectionState == ConnectionState.waiting) return _loading();

                  if (!adminSnap.hasData || !adminSnap.data!.exists) {
                    FirebaseAuth.instance.signOut();
                    return const LoginView();
                  }

                  // Registrar token para admin
                  NotificationService().registrarToken();
                  return const AdminHomeView();
                },
              );
            }

            final data = firestoreSnap.data!.data() as Map<String, dynamic>;
            final rol = data['rol'] ?? '';
            final estado = data['estado'] ?? '';

            // Registrar token para usuario/conductor
            NotificationService().registrarToken();

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
    body: Center(
      child: CircularProgressIndicator(),
    ),
  );
}