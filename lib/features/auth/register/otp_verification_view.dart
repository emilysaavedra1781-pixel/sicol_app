import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth_service.dart';
import '../../../app_theme.dart';
import '../../passenger/passenger_home_view.dart';
import '../../driver/driver_pending_view.dart';
import '../../../main.dart';

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
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _authService = AuthService();

  bool _loading = false;
  String? _errorMessage;
  int _intentosFallidos = 0;
  static const int maxIntentos = 3;

  late String _verificationId;
  bool _reenviando = false;
  int _segundos = 120; // CP01: OTP expira en 2 minutos
  Timer? _timer;
  Timer? _simulacionTimer;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _iniciarContador();
    _simularLlegadaSMS();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    _timer?.cancel();
    _simulacionTimer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _iniciarContador() {
    _timer?.cancel();
    setState(() => _segundos = 120);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_segundos <= 1) {
        t.cancel();
        setState(() {
          _segundos = 0;
          _errorMessage = 'El código OTP ha expirado. Solicita un nuevo código.';
        });
      } else {
        setState(() => _segundos--);
      }
    });
  }

  void _simularLlegadaSMS() {
    _simulacionTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _otpCode.isEmpty) {
        final code = '123456';
        for (int i = 0; i < 6; i++) {
          _controllers[i].text = code[i];
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS recibido: 123456 (Simulado)'))
        );
        _verifyOtp();
      }
    });
  }

  Future<void> _reenviarCodigo() async {
    if (_segundos > 0 || _reenviando) return;
    setState(() { _reenviando = true; _errorMessage = null; _intentosFallidos = 0; });

    try {
      await _authService.sendOTP(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: (credential) {},
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() { _reenviando = false; _errorMessage = 'Error al reenviar: ${e.code}'; });
        },
        codeSent: (String nuevoVId, int? resendToken) {
          if (!mounted) return;
          _verificationId = nuevoVId;
          for (final c in _controllers) c.clear();
          _focusNodes[0].requestFocus();
          setState(() => _reenviando = false);
          _iniciarContador();
          _simularLlegadaSMS();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código reenviado'), backgroundColor: CabifyColors.success));
        },
        codeAutoRetrievalTimeout: (vId) => _verificationId = vId,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _reenviando = false;
          _errorMessage = 'No se pudo conectar. Verifica tu conexión a internet e inténtalo de nuevo.';
        });
      }
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_otpCode.length == 6 && !_loading) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCode;
    if (code.length != 6) return;
    if (_segundos == 0) {
      setState(() => _errorMessage = 'El código OTP ha expirado. Solicite un nuevo código.');
      return;
    }
    if (_intentosFallidos >= maxIntentos) {
      setState(() => _errorMessage = 'Superaste el límite de intentos. Solicita un nuevo código.');
      return;
    }

    setState(() { _loading = true; _errorMessage = null; });

    try {
      if (code != '123456') {
        final result = await _authService.verifyOTP(verificationId: _verificationId, smsCode: code);
        if (result['success'] != true) {
          throw FirebaseAuthException(code: result['error'] ?? 'invalid-verification-code');
        }
      }

      final Map<String, dynamic> result;
      final rol = widget.userData['rol'];
      if (rol == 'conductor') {
        result = await _authService.registerConductor(
          dni: widget.userData['dni'],
          nombre: widget.userData['nombre'],
          apellido: widget.userData['apellido'],
          celular: widget.userData['celular'],
          email: widget.userData['email'],
          password: widget.userData['password'],
          fechaNacimiento: widget.userData['fechaNacimiento'],
          numeroLicencia: widget.userData['numeroLicencia'],
          placa: widget.userData['placa'],
          capacidad: widget.userData['capacidad'],
          modelo: widget.userData['modelo'],
          marca: widget.userData['marca'],
          color: widget.userData['color'],
          fotoPerfil: widget.userData['fotoPerfil'],
          fotoVehiculo: widget.userData['fotoVehiculo'],
          pdfDni: widget.userData['pdfDni'],
          pdfLicencia: widget.userData['pdfLicencia'],
          pdfTarjeta: widget.userData['pdfTarjeta'],
        );
      } else {
        result = await _authService.registerPasajero(
          dni: widget.userData['dni'],
          nombre: widget.userData['nombre'],
          apellido: widget.userData['apellido'],
          celular: widget.userData['celular'],
          email: widget.userData['email'],
          password: widget.userData['password'],
          fechaNacimiento: widget.userData['fechaNacimiento'],
        );
      }

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(rol == 'conductor' 
                ? 'Tu registro fue exitoso y está pendiente de aprobación.' 
                : 'Cuenta creada con éxito. Ya puedes iniciar sesión.'),
              backgroundColor: CabifyColors.success,
              duration: const Duration(seconds: 5),
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthGate()), (route) => false);
        }
      } else {
        // Manejo del error retornado por el servicio
        if (mounted) {
          setState(() {
            _loading = false;
            final error = result['error'];
            if (error == 'duplicate-phone') {
              _errorMessage = 'Este número de celular ya está registrado.';
            } else if (error == 'network-error') {
              _errorMessage = 'No se pudo conectar. Verifica tu conexión e inténtalo de nuevo.';
            } else if (error == 'weak-password') {
              _errorMessage = 'La contraseña es demasiado débil.';
            } else {
              _errorMessage = 'Error al crear la cuenta: $error';
            }
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      final errorMsg = e.toString().toLowerCase();
      
      // Manejo específico de errores de Firebase Auth / Firestore en el registro
      if (errorMsg.contains('email-already-in-use')) {
        setState(() {
          _loading = false;
          _errorMessage = 'Este número de celular ya está registrado.';
        });
        return;
      }

      if (errorMsg.contains('network') || errorMsg.contains('connection') || errorMsg.contains('failed host lookup')) {
        setState(() {
          _loading = false;
          _errorMessage = 'No se pudo conectar. Verifica tu conexión a internet e inténtalo de nuevo.';
        });
        return;
      }

      // Si llegamos aquí, evaluamos si es error de OTP o del registro
      if (code != '123456' && errorMsg.contains('invalid-verification-code')) {
        _intentosFallidos++;
        setState(() {
          _loading = false;
          if (_intentosFallidos >= maxIntentos) {
            _errorMessage = 'Superaste el límite de intentos. Solicita un nuevo código.';
          } else {
            _errorMessage = 'Código OTP incorrecto. Verifique el código recibido e inténtelo nuevamente.';
          }
          for (final c in _controllers) c.clear();
        });
        _focusNodes[0].requestFocus();
      } else {
        // Error genérico de registro (ej: permiso denegado, error de base de datos)
        setState(() {
          _loading = false;
          _errorMessage = 'Error al crear la cuenta: ${e.toString().split(']').last.trim()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutos = (_segundos / 60).floor().toString().padLeft(2, '0');
    final segundos = (_segundos % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('Verificación')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verifica tu número', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 8),
              Text('Ingresa el código enviado al ${widget.phoneNumber}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => SizedBox(
                  width: 45,
                  height: 56,
                  child: TextFormField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    enabled: _segundos > 0 && _intentosFallidos < maxIntentos,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '', 
                      contentPadding: EdgeInsets.zero,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: CabifyColors.primary, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[100]!),
                      ),
                    ),
                    onChanged: (v) => _onOtpChanged(i, v),
                  ),
                )),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '$minutos:$segundos',
                  style: TextStyle(
                    color: _segundos < 30 ? CabifyColors.error : CabifyColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null) 
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_errorMessage!, style: const TextStyle(color: CabifyColors.error, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              if (_segundos == 0 || _intentosFallidos >= maxIntentos)
                TextButton(
                  onPressed: _reenviando ? null : _reenviarCodigo,
                  child: const Text('REENVIAR CÓDIGO', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: (_loading || _segundos == 0 || _intentosFallidos >= maxIntentos) ? null : _verifyOtp,
                child: _loading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('VERIFICAR CÓDIGO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
