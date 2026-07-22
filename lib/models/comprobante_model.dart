import 'package:cloud_firestore/cloud_firestore.dart';

class ComprobanteModel {
  final String codigoComprobante;
  final DateTime fechaEmision;
  final String viajeroNombre;
  final String conductorNombre;
  final String placaVehiculo;
  final int asiento;
  final String paradero;
  final String codigoVerificacion;
  final double monto;
  final String? paymentId;

  ComprobanteModel({
    required this.codigoComprobante,
    required this.fechaEmision,
    required this.viajeroNombre,
    required this.conductorNombre,
    required this.placaVehiculo,
    required this.asiento,
    required this.paradero,
    required this.codigoVerificacion,
    required this.monto,
    this.paymentId,
  });

  factory ComprobanteModel.fromFirestore(Map<String, dynamic> data, String fallbackId) {
    final comp = data['comprobante'] as Map<String, dynamic>?;
    
    return ComprobanteModel(
      codigoComprobante: comp?['codigoComprobante'] ?? fallbackId.substring(0, 8).toUpperCase(),
      fechaEmision: (comp?['fechaEmision'] as Timestamp?)?.toDate() 
          ?? (data['creadoEn'] as Timestamp?)?.toDate() 
          ?? DateTime.now(),
      viajeroNombre: comp?['viajeroNombre'] ?? data['nombreViajero'] ?? '-',
      conductorNombre: comp?['conductorNombre'] ?? 'Conductor Sicol',
      placaVehiculo: comp?['placaVehiculo'] ?? '-',
      asiento: (comp?['asiento'] as num?)?.toInt() ?? (data['numeroAsiento'] as num?)?.toInt() ?? 0,
      paradero: comp?['paradero'] ?? data['paradero'] ?? '-',
      codigoVerificacion: comp?['codigoVerificacion'] ?? data['codigoVerificacion'] ?? '-',
      monto: (comp?['monto'] as num?)?.toDouble() ?? (data['monto'] as num?)?.toDouble() ?? 15.0,
      paymentId: data['paymentId']?.toString(),
    );
  }

  String get fechaFormateada => '${fechaEmision.day}/${fechaEmision.month}/${fechaEmision.year} '
      '${fechaEmision.hour.toString().padLeft(2, '0')}:${fechaEmision.minute.toString().padLeft(2, '0')}';
  
  String get montoFormateado => 'S/ ${monto.toStringAsFixed(2)}';
}
