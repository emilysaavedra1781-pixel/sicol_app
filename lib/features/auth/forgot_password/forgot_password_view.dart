import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/auth_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../app_theme.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _celularCtrl = TextEditingController();
  final _authService = AuthService();

  String _paso = 'celular';
  bool _loading = false;
  String? _errorMessage;

  // ── OTP en memoria (RF03 / RF46) ──────────────────────────────────────────
  String? _otpEnMemoria;
  DateTime? _expiracionOtp;
  Timer? _timerOtp;
  int _segundosRestantes = 0;

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscurePass2 = true;
  Map<String, dynamic>? _userData;

  @override
  void dispose() {
    _timerOtp?.cancel();
    _celularCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timerOtp?.cancel();
    _segundosRestantes = 120; // 2 minutos
    _timerOtp = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosRestantes > 0) {
        if (mounted) setState(() => _segundosRestantes--);
      } else {
        timer.cancel();
      }
    });
  }

  String _generarCodigoRandom() {
    final rnd = Random();
    return (100000 + rnd.nextInt(900000)).toString();
  }

  void _autocompletarOtp(String code) {
    for (int i = 0; i < 6; i++) {
      _otpControllers[i].text = code[i];
    }
  }

  // ─── PASO 1: Verificar celular y enviar OTP ───────────────────────────────

  Future<void> _enviarOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final celular = _celularCtrl.text.trim();
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('celular', isEqualTo: celular)
          .limit(1)
          .get();

      if (!mounted) return;

      if (snap.docs.isEmpty) {
        setState(() {
          _loading = false;
          // CP02: Mensaje de celular no registrado
          _errorMessage = 'Este número no está registrado en el sistema.';
        });
        return;
      }

      _userData = snap.docs.first.data();
      _userData!['id'] = snap.docs.first.id;

      // Generar OTP en memoria para todos (Passenger y Conductor)
      _otpEnMemoria = _generarCodigoRandom();
      _expiracionOtp = DateTime.now().add(const Duration(minutes: 2));
      
      setState(() {
        _loading = false;
        _paso = 'otp';
        _autocompletarOtp(_otpEnMemoria!); // CP01: Autocompletar
        _startTimer();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código enviado por SMS (Simulado)')),
      );
    } catch (e) {
      // CP05: Error de conexión
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'No se pudo conectar. Verifica tu conexión a internet e inténtalo de nuevo.';
        });
      }
    }
  }

  // ─── PASO 2: Verificar OTP ────────────────────────────────────────────────

  Future<void> _verificarOtp() async {
    final code = _otpControllers.map((c) => c.text.trim()).join();
    if (code.length != 6) return;

    // CP04: Verificar expiración
    if (_segundosRestantes == 0) {
      setState(() {
        _errorMessage = 'El código OTP ha expirado. Solicita un nuevo código.';
      });
      return;
    }

    // CP03: Verificar corrección
    if (code != _otpEnMemoria) {
      setState(() {
        _errorMessage = 'Código incorrecto. Verifique el código e inténtelo nuevamente.';
      });
      return;
    }

    setState(() {
      _paso = 'password';
      _errorMessage = null;
    });
  }

  // ─── PASO 3: Cambiar contraseña ───────────────────────────────────────────

  Future<void> _cambiarPassword() async {
    if (_passCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'Ingresa una contraseña.');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _errorMessage = 'La contraseña debe tener mínimo 6 caracteres.');
      return;
    }
    if (_passCtrl.text != _pass2Ctrl.text) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final uid = _userData!['id'];
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('changePassword');

      await callable.call({
        'uid': uid,
        'newPassword': _passCtrl.text,
      });

      // Desbloqueo automático y reset intentos (RF40 / RF03)
      await _authService.desbloquearCuentaPorCelular(_celularCtrl.text.trim());

      if (!mounted) return;
      setState(() {
        _loading = false;
        _paso = 'exito';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'No se pudo conectar. Verifica tu conexión a internet e inténtalo de nuevo.';
        });
      }
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _paso != 'exito'
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: CabifyColors.primary),
                onPressed: () => _paso == 'otp' ? setState(() => _paso = 'celular') : Navigator.pop(context),
              ),
              title: const Text('Recuperar contraseña',
                  style: TextStyle(color: CabifyColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: _buildPaso(),
        ),
      ),
    );
  }

  Widget _buildPaso() {
    switch (_paso) {
      case 'celular': return _buildCelularStep();
      case 'otp': return _buildOtpStep();
      case 'password': return _buildPasswordStep();
      case 'exito': return _buildExitoStep();
      default: return _buildCelularStep();
    }
  }

  Widget _buildCelularStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ingresa tu número de celular para recibir un código de verificación.',
              style: TextStyle(color: CabifyColors.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 32),
          if (_errorMessage != null) ...[ _errorBanner(_errorMessage!), const SizedBox(height: 20) ],
          const Text('Número de celular', style: TextStyle(color: CabifyColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _celularCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: CabifyColors.textPrimary, fontSize: 15),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu celular' : (v.length != 9 ? '9 dígitos requeridos' : null),
            decoration: _inputDecoration(hint: '9XXXXXXXX', icon: Icons.phone_outlined, prefix: const Padding(padding: EdgeInsets.only(left: 12, right: 4), child: Text('+51 ', style: TextStyle(color: CabifyColors.textPrimary, fontSize: 14)))),
          ),
          const SizedBox(height: 32),
          _botonPrincipal(texto: 'Continuar', onPressed: _loading ? null : _enviarOtp, loading: _loading),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    final expirado = _segundosRestantes == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(expirado ? 'El código ha expirado. Solicita uno nuevo.' : 'Ingresa el código de verificación enviado por SMS.',
            style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 14, height: 1.5)),
        const SizedBox(height: 32),
        if (_errorMessage != null) ...[ _errorBanner(_errorMessage!), const SizedBox(height: 20) ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => SizedBox(
            width: 44,
            height: 56,
            child: TextFormField(
              controller: _otpControllers[i],
              focusNode: _otpFocusNodes[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              enabled: !expirado && !_loading,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: CabifyColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CabifyColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CabifyColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CabifyColors.primary, width: 2)),
              ),
              onChanged: (v) {
                if (v.length == 1 && i < 5) _otpFocusNodes[i + 1].requestFocus();
                else if (v.isEmpty && i > 0) _otpFocusNodes[i - 1].requestFocus();
                if (_otpControllers.every((c) => c.text.isNotEmpty)) _verificarOtp();
              },
            ),
          )),
        ),
        const SizedBox(height: 20),
        Center(child: Text('${(_segundosRestantes ~/ 60).toString().padLeft(2, '0')}:${(_segundosRestantes % 60).toString().padLeft(2, '0')}', style: TextStyle(color: expirado ? CabifyColors.error : CabifyColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold))),
        const SizedBox(height: 32),
        expirado 
          ? _botonSecundario(texto: 'Reenviar OTP', onPressed: _enviarOtp)
          : _botonPrincipal(texto: 'Verificar', onPressed: _loading ? null : _verificarOtp, loading: _loading),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Crea tu nueva contraseña.', style: TextStyle(color: CabifyColors.textSecondary, fontSize: 14, height: 1.5)),
        const SizedBox(height: 32),
        if (_errorMessage != null) ...[ _errorBanner(_errorMessage!), const SizedBox(height: 20) ],
        const Text('Nueva contraseña', style: TextStyle(color: CabifyColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(controller: _passCtrl, obscureText: _obscurePass, style: const TextStyle(color: CabifyColors.textPrimary, fontSize: 15), decoration: _inputDecoration(hint: '••••••••', icon: Icons.lock_outline, suffixIcon: IconButton(icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: CabifyColors.textSecondary, size: 20), onPressed: () => setState(() => _obscurePass = !_obscurePass)))),
        const SizedBox(height: 16),
        const Text('Confirmar contraseña', style: TextStyle(color: CabifyColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(controller: _pass2Ctrl, obscureText: _obscurePass2, style: const TextStyle(color: CabifyColors.textPrimary, fontSize: 15), decoration: _inputDecoration(hint: '••••••••', icon: Icons.lock_outline, suffixIcon: IconButton(icon: Icon(_obscurePass2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: CabifyColors.textSecondary, size: 20), onPressed: () => setState(() => _obscurePass2 = !_obscurePass2)))),
        const SizedBox(height: 32),
        _botonPrincipal(texto: 'Cambiar contraseña', onPressed: _loading ? null : _cambiarPassword, loading: _loading),
      ],
    );
  }

  Widget _buildExitoStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(width: 80, height: 80, decoration: BoxDecoration(color: CabifyColors.success.withValues(alpha: 0.12), shape: BoxShape.circle), child: const Icon(Icons.check_circle_outline, color: CabifyColors.success, size: 40)),
        const SizedBox(height: 24),
        const Text('¡Contraseña actualizada correctamente!', style: TextStyle(color: CabifyColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text('Tu contraseña fue cambiada exitosamente.\nTu cuenta ha sido desbloqueada.', textAlign: TextAlign.center, style: TextStyle(color: CabifyColors.textSecondary, fontSize: 14, height: 1.6)),
        const SizedBox(height: 40),
        _botonPrincipal(texto: 'Volver al inicio de sesión', onPressed: () => Navigator.pop(context), loading: false),
      ],
    );
  }

  Widget _errorBanner(String msg) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: CabifyColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: CabifyColors.error.withValues(alpha: 0.3))), child: Row(children: [const Icon(Icons.error_outline, color: CabifyColors.error, size: 18), const SizedBox(width: 10), Expanded(child: Text(msg, style: const TextStyle(color: CabifyColors.error, fontSize: 13)))]));

  Widget _botonPrincipal({required String texto, required VoidCallback? onPressed, required bool loading}) => SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));

  Widget _botonSecundario({required String texto, required VoidCallback onPressed}) => SizedBox(width: double.infinity, height: 52, child: OutlinedButton(onPressed: onPressed, style: OutlinedButton.styleFrom(foregroundColor: CabifyColors.primary, side: const BorderSide(color: CabifyColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));

  InputDecoration _inputDecoration({required String hint, required IconData icon, Widget? suffixIcon, Widget? prefix}) => InputDecoration(hintText: hint, hintStyle: const TextStyle(color: CabifyColors.textSecondary), prefixIcon: prefix ?? Icon(icon, color: CabifyColors.textSecondary, size: 20), suffixIcon: suffixIcon, filled: true, fillColor: const Color(0xFFF9FAFB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CabifyColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CabifyColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CabifyColors.primary, width: 1.5)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CabifyColors.error)), focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CabifyColors.error, width: 1.5)), errorStyle: const TextStyle(color: CabifyColors.error, fontSize: 12), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16));
}
