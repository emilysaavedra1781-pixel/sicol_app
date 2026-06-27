import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;

  /// Pide permiso y guarda el token FCM del usuario actual en Firestore.
  /// Llamar esto justo después de un login exitoso.
  Future<void> registrarToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _messaging.requestPermission();

    final token = await _messaging.getToken();
    if (token == null) return;

    await _db.collection('usuarios').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );

    // Si el token se renueva (pasa de vez en cuando), lo actualizamos también.
    _messaging.onTokenRefresh.listen((nuevoToken) {
      _db.collection('usuarios').doc(uid).set(
        {'fcmToken': nuevoToken},
        SetOptions(merge: true),
      );
    });
  }

  /// RF30/RF42 — Parte 3: maneja notificaciones cuando la app está abierta
  /// (foreground) y cuando el usuario toca una notificación que llegó
  /// con la app en background.
  ///
  /// [navigatorKey] se usa para mostrar el SnackBar y, si se desea,
  /// navegar según el campo `tipo` que viene en `data`.
  ///
  /// Llamar esto UNA sola vez, normalmente en main.dart dentro de
  /// initState/build de tu widget raíz (o justo después de runApp).
  void escucharNotificaciones(GlobalKey<NavigatorState> navigatorKey) {
    // ── Caso 1: app abierta y visible (foreground) ────────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      final titulo = message.notification?.title ?? 'Nueva notificación';
      final cuerpo = message.notification?.body ?? '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    if (cuerpo.isNotEmpty)
                      Text(cuerpo,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E6BFF),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    });

    // ── Caso 2: el usuario toca la notificación y la app pasa a foreground
    // (estaba en background, no cerrada del todo) ─────────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _manejarTap(message);
    });

    // ── Caso 3: la app estaba completamente cerrada y se abrió tocando
    // la notificación ──────────────────────────────────────────────────────
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _manejarTap(message);
      }
    });
  }

  void _manejarTap(RemoteMessage message) {
    final tipo = message.data['tipo'];
    // Por ahora solo se registra; si luego se quiere navegar a una
    // pantalla específica (ej. DriverTripView con el viajeId), se
    // puede usar navigatorKey.currentState?.push(...) aquí usando
    // message.data['viajeId'].
    debugPrint('Notificación tocada — tipo: $tipo, data: ${message.data}');
  }
}