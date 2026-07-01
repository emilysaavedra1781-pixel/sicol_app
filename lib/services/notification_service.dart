import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'booking_service.dart';
import '../app_theme.dart';
import '../features/passenger/calificacion_view.dart';

class NotificationService {
  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;

  /// Pide permiso y guarda el token FCM del usuario actual en Firestore.
  /// Llamar esto justo después de un login exitoso.
  Future<void> registrarToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _messaging.requestPermission();

    final token = await _messaging.getToken();
    if (token == null) return;

    // Verificar si el usuario es un Admin (basado en el email o consultando Firestore)
    final userDoc = await _db.collection('usuarios').doc(user.uid).get();
    
    if (userDoc.exists) {
      await _db.collection('usuarios').doc(user.uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
    } else {
      await _db.collection('admins').doc(user.uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
    }

    _messaging.onTokenRefresh.listen((nuevoToken) async {
      final currentDoc = await _db.collection('usuarios').doc(user.uid).get();
      final collection = currentDoc.exists ? 'usuarios' : 'admins';
      await _db.collection(collection).doc(user.uid).set(
        {'fcmToken': nuevoToken},
        SetOptions(merge: true),
      );
    });
  }

  void escucharNotificaciones(GlobalKey<NavigatorState> navigatorKey) {
    // ── Caso 1: app abierta y visible (foreground) ────────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      final tipo = message.data['tipo'];
      if (tipo == 'asiento_liberado') {
        _mostrarDialogoReasignacion(context, message);
        return;
      }

      final titulo = message.notification?.title ?? 'Nueva notificación';
      final cuerpo = message.notification?.body ?? '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    if (cuerpo.isNotEmpty)
                      Text(cuerpo, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E6BFF),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    });

    // ── Caso 2: el usuario toca la notificación y la app pasa a foreground
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        if (message.data['tipo'] == 'asiento_liberado') {
          _mostrarDialogoReasignacion(context, message);
        } else if (message.data['tipo'] == 'viaje_finalizado') {
          _navegarACalificacion(context, message);
        }
      }
      _manejarTap(message);
    });

    // ── Caso 3: la app estaba completamente cerrada
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          if (message.data['tipo'] == 'asiento_liberado') {
            _mostrarDialogoReasignacion(context, message);
          } else if (message.data['tipo'] == 'viaje_finalizado') {
            _navegarACalificacion(context, message);
          }
        }
        _manejarTap(message);
      }
    });
  }

  void _manejarTap(RemoteMessage message) {
    final tipo = message.data['tipo'];
    debugPrint('Notificación tocada — tipo: $tipo, data: ${message.data}');
  }

  void _navegarACalificacion(BuildContext context, RemoteMessage message) {
    final data = message.data;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalificacionView(
          viajeId: data['viajeId'] ?? '',
          reservaId: data['reservaId'] ?? '',
          conductorUid: data['conductorUid'] ?? '',
          conductorNombre: data['conductorNombre'] ?? 'Conductor',
          rutaLabel: data['rutaLabel'] ?? 'Viaje finalizado',
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoReasignacion(BuildContext context, RemoteMessage message) async {
    final viajeId = message.data['viajeId'];
    final asientoLibreStr = message.data['asientoLibre'];
    final asientoLibre = int.tryParse(asientoLibreStr ?? '');
    
    if (viajeId == null || asientoLibre == null) return;

    final bookingService = BookingService();
    final reservaId = await bookingService.getReservaIdForUserInTrip(viajeId);

    if (reservaId == null) return; 

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🪑 Asiento disponible'),
        content: Text('Se liberó el asiento $asientoLibre. ¿Deseas cambiarte a este asiento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await bookingService.cambiarAsiento(
                  reservaId: reservaId, 
                  viajeId: viajeId, 
                  nuevoAsiento: asientoLibre
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Asiento cambiado con éxito!'), backgroundColor: CabifyColors.success)
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: CabifyColors.error)
                  );
                }
              }
            },
            child: const Text('ACEPTAR CAMBIO'),
          ),
        ],
      ),
    );
  }
}
