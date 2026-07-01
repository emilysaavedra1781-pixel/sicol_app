import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentService {
  final String _publicKey = 'APP_USR-11a5710b-c686-4fb2-919d-7f5d658fdbe9';
  final String _accessToken = 'APP_USR-4677321431024821-062723-8239934beb80330c6fe2582abe8d3026-3502535930';

  /// Obtiene un token de tarjeta desde MercadoPago
  Future<String> _getCardToken({
    required String cardNumber,
    required String securityCode,
    required int expirationMonth,
    required int expirationYear,
    required String cardholderEmail,
  }) async {
    final url = Uri.parse('https://api.mercadopago.com/v1/card_tokens?public_key=$_publicKey');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'card_number': cardNumber.replaceAll(' ', ''),
        'security_code': securityCode,
        'expiration_month': expirationMonth,
        'expiration_year': expirationYear,
        'cardholder': {
          'email': cardholderEmail,
        },
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['id'];
    } else {
      throw Exception('Error al obtener token de tarjeta: ${response.body}');
    }
  }

  /// Procesa el pago en soles (PEN) usando el token de tarjeta
  Future<String> processPayment({
    required double amount,
    required String email,
    required String cardNumber,
    required String securityCode,
    required int expirationMonth,
    required int expirationYear,
  }) async {
    try {
      // 1. Obtener Token
      final cardToken = await _getCardToken(
        cardNumber: cardNumber,
        securityCode: securityCode,
        expirationMonth: expirationMonth,
        expirationYear: expirationYear,
        cardholderEmail: email,
      );

      // 2. Crear Pago
      final url = Uri.parse('https://api.mercadopago.com/v1/payments');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          'transaction_amount': amount,
          'token': cardToken,
          'description': 'Reserva de Colectivo',
          'installments': 1,
          'payment_method_id': 'visa', // Simplificado para prueba
          'payer': {
            'email': email,
          },
          'currency_id': 'PEN',
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data['status']; // approved, rejected, pending
      } else {
        return 'error: ${data['message'] ?? 'Desconocido'}';
      }
    } catch (e) {
      return 'error: $e';
    }
  }
}
