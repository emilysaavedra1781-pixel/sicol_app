import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth_service.dart';
import '../../passenger/passenger_home_view.dart';

class OtpVerificationView extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final Map<String, dynamic> userData;

  const OtpVerificationView({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.userData,
  });

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView> {
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _authService = AuthService();

  bool _loading = false;
  String? _errorMessage;
  int _intentosFallidos = 0;
  static const int maxIntentos = 3;

  String get _otpCode => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_otpCode.length == 6) _verifyOtp();
  }

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 6) return;
    if (_intentosFallidos >= maxIntentos) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Paso 1: verificar OTP → obtiene UserCredential con uid del phone
      final userCredential = await _authService.verifyOTP(
        verificationId: widget.verificationId,
        smsCode: _otpCode,
      );

      // Paso 2: vincular email+pass y guardar en Firestore
      await _authService.registerUser(
        uid: userCredential.user!.uid,
        dni: widget.userData['dni'],
        nombre: widget.userData['nombre'],
        apellido: widget.userData['apellido'],
        celular: widget.userData['celular'],
        email: widget.userData['email'],
        password: widget.userData['password'],
        fechaNacimiento: widget.userData['fechaNacimiento'],
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Cuenta creada exitosamente!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PassengerHomeView()),
            (route) => false,
      );
    } on FirebaseAuthException {
      if (!mounted) return;
      _intentosFallidos++;
      final restantes = maxIntentos - _intentosFallidos;

      setState(() {
        _loading = false;
        _errorMessage = _intentosFallidos >= maxIntentos
            ? 'Código incorrecto. Agotaste los intentos. Vuelve atrás.'
            : 'Código incorrecto. Te quedan $restantes intento(s).';
        for (final c in _controllers) { c.clear(); }
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final agotado = _intentosFallidos >= maxIntentos;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Verificar número',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Ingresa el código enviado a\n${widget.phoneNumber}',
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 46,
                    height: 56,
                    child: TextFormField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      enabled: !agotado && !_loading,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFF111827),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: Color(0xFF1F2937)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: Color(0xFF1F2937)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF1E6BFF), width: 2),
                        ),
                      ),
                      onChanged: (v) => _onOtpChanged(i, v),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFFF3B30), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                color: Color(0xFFFF3B30), fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              if (!agotado)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                        : const Text('Verificar',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (agotado)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E6BFF),
                      side: const BorderSide(color: Color(0xFF1E6BFF)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Volver e intentar de nuevo',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}