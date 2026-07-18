import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  // Callback que se ejecuta cuando llega un link de pago
  void Function(String status)? onPaymentResult;

  // Almacenamos el contexto del último intento de compra para el ciclo de reservas múltiples
  Map<String, dynamic>? lastPurchaseContext;

  Future<void> init() async {
    // 1. Revisar si la app se abrió DESDE un link (app estaba cerrada)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      if (kDebugMode) print('Error obteniendo initial link: $e');
    }

    // 2. Escuchar links mientras la app está abierta/en segundo plano
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    }, onError: (err) {
      if (kDebugMode) print('Error en uriLinkStream: $err');
    });
  }

  void _handleUri(Uri uri) {
    if (kDebugMode) print('Deep link recibido: $uri');

    // uri.scheme = "sicolapp", uri.host = "payment-success" / "payment-error" / "payment-pending"
    if (uri.scheme == 'sicolapp') {
      final status = uri.host; // payment-success, payment-error, payment-pending
      onPaymentResult?.call(status);
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}