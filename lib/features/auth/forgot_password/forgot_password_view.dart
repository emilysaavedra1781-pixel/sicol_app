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
  final _emailCtrl = TextEditingController();
  final _authService = AuthService();

  String _paso = 'email';
  bool _loading = false;
  String? _errorMessage;

  // ── OTP en memoria (RF03 / RF46) ──────────────────────────────────────────
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
  String? _capturedUid;

  @override
  void dispose() {
    _timerOtp?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timerOtp?.cancel();
    _segundosRestantes = 60; // 60 segundos reales
    _timerOtp = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosRestantes > 0) {
        if (mounted) setState(() => _segundosRestantes--);
      } else {
        timer.cancel();
      }
    });
  }

  // ─── PASO 1: Enviar OTP Real via Cloud Function ───────────────────────────

  Future<void> _enviarOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailCtrl.text.trim();
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('solicitarOtpRecuperacion');
      
      await callable.call({'email': email});

      if (!mounted) return;
      setState(() {
        _loading = false;
        _paso = 'otp';
        for (var c in _otpControllers) c.clear();
        _startTimer();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código enviado a tu correo electrónico.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.toString().replaceAll("Exception: ", "").replaceAll("FirebaseFunctionsException: ", "");
          if (_errorMessage!.contains("not-found")) _errorMessage = "El correo no está registrado.";
          if (_errorMessage!.contains("resource-exhausted")) _errorMessage = "Espera un minuto para reenviar.";
        });
      }
    }
  }

  // ─── PASO 2: Verificar OTP Real ───────────────────────────────────────────

  Future<void> _verificarOtp() async {
    final code = _otpControllers.map((c) => c.text.trim()).join();
    if (code.length != 6) return;

    if (_segundosRestantes == 0) {
      setState(() => _errorMessage = 'El código ha expirado. Solicita uno nuevo.');
      return;
    }

    setState(() => _loading = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('verificarOtpRecuperacion');
      
      final result = await callable.call({
        'email': _emailCtrl.text.trim(),
        'otp': code,
      });

      if (!mounted) return;
      setState(() {
        _loading = false;
        _capturedUid = result.data['uid'];
        _paso = 'password';
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = "Código incorrecto o expirado.";
        });
      }
    }
  }

  // ─── PASO 3: Cambiar contraseña con Admin SDK (vía Function segura) ──────

  Future<void> _cambiarPassword() async {
    if (_passCtrl.text.length < 6) {
      setState(() => _errorMessage = 'Mínimo 6 caracteres.');
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
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('changePasswordSecure');

      await callable.call({
        'uid': _capturedUid,
        'newPassword': _passCtrl.text,
      });

      if (!mounted) return;
      setState(() {
        _loading = false;
        _paso = 'exito';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'No se pudo actualizar la contraseña. Reintenta.';
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
                onPressed: () {
                  if (_paso == 'otp') setState(() => _paso = 'email');
                  else if (_paso == 'password') setState(() => _paso = 'otp');
                  else Navigator.pop(context);
                },
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
      case 'email': return _buildEmailStep();
      case 'otp': return _buildOtpStep();
      case 'password': return _buildPasswordStep();
      case 'exito': return _buildExitoStep();
      default: return _buildEmailStep();
    }
  }

  Widget _buildEmailStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ingresa tu correo electrónico registrado para recibir un código de verificación.',
              style: TextStyle(color: CabifyColors.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 32),
          if (_errorMessage != null) ...[ _errorBanner(_errorMessage!), const SizedBox(height: 20) ],
          const Text('Correo electrónico', style: TextStyle(color: CabifyColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: CabifyColors.textPrimary, fontSize: 15),
            validator: (v) => (v == null || !v.contains('@')) ? 'Email inválido' : null,
            decoration: _inputDecoration(hint: 'usuario@email.com', icon: Icons.email_outlined),
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
        Text(expirado ? 'El código ha expirado. Solicita uno nuevo.' : 'Ingresa el código de 6 dígitos enviado a tu correo electrónico.',
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
          ? _botonSecundario(texto: 'Reenviar código', onPressed: _enviarOtp)
          : _botonPrincipal(texto: 'Verificar código', onPressed: _loading ? null : _verificarOtp, loading: _loading),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Crea tu nueva contraseña de acceso.', style: TextStyle(color: CabifyColors.textSecondary, fontSize: 14, height: 1.5)),
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
        const Text('¡Proceso exitoso!', style: TextStyle(color: CabifyColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text('Tu contraseña ha sido actualizada y tu cuenta está lista para usar.', textAlign: TextAlign.center, style: TextStyle(color: CabifyColors.textSecondary, fontSize: 14, height: 1.6)),
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
