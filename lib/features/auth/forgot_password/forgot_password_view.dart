import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth_service.dart';

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
  String? _verificationId;
  int _intentosOtp = 0;
  static const int maxIntentos = 3;

  final List<TextEditingController> _otpControllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
  List.generate(6, (_) => FocusNode());

  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscurePass2 = true;

  String get _otpCode =>
      _otpControllers.map((c) => c.text.trim()).join();

  @override
  void dispose() {
    _celularCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    super.dispose();
  }

  Future<void> _enviarOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final celular = _celularCtrl.text.trim();
    final existe = await _authService.isCelularRegistered(celular);
    if (!mounted) return;

    if (!existe) {
      setState(() {
        _loading = false;
        _errorMessage = 'No existe una cuenta con ese número de celular.';
      });
      return;
    }

    // MODO PRUEBA: saltar envío de OTP, ir directo a pantalla OTP
    setState(() {
      _loading = false;
      _verificationId = 'test-verification-id';
      _paso = 'otp';
    });
  }

  Future<void> _verificarOtp() async {
    final code = _otpCode;
    if (code.length != 6) return;
    if (_intentosOtp >= maxIntentos) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // MODO PRUEBA: código universal 123456
      if (code != '123456') {
        await _authService.verifyOTP(
          verificationId: _verificationId ?? '',
          smsCode: code,
        );
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _paso = 'password';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _intentosOtp++;
      setState(() {
        _loading = false;
        for (final c in _otpControllers) c.clear();
        _otpFocusNodes[0].requestFocus();
        if (_intentosOtp >= maxIntentos) {
          _errorMessage = 'OTP incorrecto. Agotaste los intentos. Vuelve atrás.';
        } else {
          _errorMessage =
          'OTP incorrecto (${e.code}). Te quedan ${maxIntentos - _intentosOtp} intento(s).';
        }
      });
    }
  }

  Future<void> _cambiarPassword() async {
    if (_passCtrl.text != _pass2Ctrl.text) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden.');
      return;
    }
    final password = _passCtrl.text;

    if (password.length < 8) {
      setState(() {
        _errorMessage = 'La contraseña debe tener al menos 8 caracteres.';
      });
      return;
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      setState(() {
        _errorMessage = 'Debe contener al menos una letra mayúscula.';
      });
      return;
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      setState(() {
        _errorMessage = 'Debe contener al menos una letra minúscula.';
      });
      return;
    }

    if (!RegExp(r'\d').hasMatch(password)) {
      setState(() {
        _errorMessage = 'Debe contener al menos un número.';
      });
      return;
    }

    if (!RegExp(r'[@$!%*?&._#\-]').hasMatch(password)) {
      setState(() {
        _errorMessage = 'Debe contener al menos un símbolo especial.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user!.updatePassword(_passCtrl.text);
      await _authService.desbloquearCuentaPorCelular(_celularCtrl.text.trim());

      if (!mounted) return;
      setState(() {
        _loading = false;
        _paso = 'exito';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Error al cambiar contraseña. Intenta nuevamente.';
      });
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    if (_otpCode.length == 6) _verificarOtp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: _paso != 'exito'
          ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () {
            if (_paso == 'otp') {
              setState(() => _paso = 'celular');
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Recuperar contraseña',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: () {
            switch (_paso) {
              case 'celular':
                return _buildCelularStep();
              case 'otp':
                return _buildOtpStep();
              case 'password':
                return _buildPasswordStep();
              case 'exito':
                return _buildExitoStep();
              default:
                return _buildCelularStep();
            }
          }(),
        ),
      ),
    );
  }

  Widget _buildCelularStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ingresa tu número de celular para recibir un código de verificación.',
            style: TextStyle(
                color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          if (_errorMessage != null) ...[
            _errorBanner(_errorMessage!),
            const SizedBox(height: 20),
          ],
          const Text('Número de celular',
              style: TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _celularCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Ingresa tu celular';
              }
              if (!RegExp(r'^\d{9}$').hasMatch(v)) {
                return 'Debe contener exactamente 9 dígitos';
              }
              if (!v.startsWith('9')) {
                return 'El celular debe comenzar con 9';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: '9XXXXXXXX',
              icon: Icons.phone_outlined,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12, right: 4),
                child: Text('+51 ',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _botonPrincipal(
            texto: 'Continuar',
            onPressed: _loading ? null : _enviarOtp,
            loading: _loading,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    final agotado = _intentosOtp >= maxIntentos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingresa el código de verificación.\nUsa el código: 123456',
          style: TextStyle(
              color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        if (_errorMessage != null) ...[
          _errorBanner(_errorMessage!),
          const SizedBox(height: 20),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 46,
              height: 56,
              child: TextFormField(
                controller: _otpControllers[i],
                focusNode: _otpFocusNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                enabled: !agotado && !_loading,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                    borderSide: const BorderSide(color: Color(0xFF1F2937)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1F2937)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    const BorderSide(color: Color(0xFF1E6BFF), width: 2),
                  ),
                ),
                onChanged: (v) => _onOtpChanged(i, v),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        if (!agotado)
          _botonPrincipal(
            texto: 'Verificar',
            onPressed: _loading ? null : _verificarOtp,
            loading: _loading,
          )
        else
          _botonSecundario(
            texto: 'Volver e intentar de nuevo',
            onPressed: () => setState(() {
              _paso = 'celular';
              _intentosOtp = 0;
              _errorMessage = null;
            }),
          ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Crea tu nueva contraseña.',
            style: TextStyle(
                color: Color(0xFF6B7280), fontSize: 14, height: 1.5)),
        const SizedBox(height: 32),
        if (_errorMessage != null) ...[
          _errorBanner(_errorMessage!),
          const SizedBox(height: 20),
        ],
        const Text('Nueva contraseña',
            style: TextStyle(
                color: Color(0xFFD1D5DB),
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _inputDecoration(
            hint: '••••••••',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF6B7280),
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Confirmar contraseña',
            style: TextStyle(
                color: Color(0xFFD1D5DB),
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _pass2Ctrl,
          obscureText: _obscurePass2,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _inputDecoration(
            hint: '••••••••',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass2
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF6B7280),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePass2 = !_obscurePass2),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _botonPrincipal(
          texto: 'Cambiar contraseña',
          onPressed: _loading ? null : _cambiarPassword,
          loading: _loading,
        ),
      ],
    );
  }

  Widget _buildExitoStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline,
              color: Color(0xFF10B981), size: 40),
        ),
        const SizedBox(height: 24),
        const Text('¡Contraseña actualizada!',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text(
          'Tu contraseña fue cambiada exitosamente.\nTu cuenta ha sido desbloqueada.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Color(0xFF6B7280), fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 40),
        _botonPrincipal(
          texto: 'Volver al inicio de sesión',
          onPressed: () => Navigator.pop(context),
          loading: false,
        ),
      ],
    );
  }

  Widget _errorBanner(String msg) => Container(
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
          child: Text(msg,
              style: const TextStyle(
                  color: Color(0xFFFF3B30), fontSize: 13)),
        ),
      ],
    ),
  );

  Widget _botonPrincipal({
    required String texto,
    required VoidCallback? onPressed,
    required bool loading,
  }) =>
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E6BFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: loading
              ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
              : Text(texto,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _botonSecundario({
    required String texto,
    required VoidCallback onPressed,
  }) =>
      SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1E6BFF),
            side: const BorderSide(color: Color(0xFF1E6BFF)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(texto,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
    Widget? prefix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF4B5563)),
        prefixIcon:
        prefix ?? Icon(icon, color: const Color(0xFF6B7280), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1F2937)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1F2937)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFF1E6BFF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF3B30)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
        ),
        errorStyle:
        const TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
}