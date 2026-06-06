import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/auth_service.dart';
import '../register/register_view.dart';
import '../forgot_password/forgot_password_view.dart';
import '../../passenger/passenger_home_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _celularCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _celularCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final result = await _authService.loginWithCelular(
      celular: _celularCtrl.text.trim(),
      password: _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PassengerHomeView()),
      );
    } else {
      setState(() {
        switch (result['error']) {
          case 'cuenta_bloqueada':
            _errorMessage =
            'Tu cuenta está bloqueada. Usa "¿Olvidaste tu contraseña?" para desbloquearla.';
            break;
          case 'usuario_no_encontrado':
            _errorMessage =
            'No existe una cuenta con ese número de celular.';
            break;
          default:
            final intentos = result['intentosRestantes'];
            _errorMessage = intentos != null
                ? 'Credenciales incorrectas. Te quedan $intentos intento(s).'
                : 'Credenciales incorrectas.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Branding
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E6BFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.directions_bus_rounded,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text('SICOL',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4)),
                      const SizedBox(height: 4),
                      const Text('Sistema de Colectivos',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                const Text('Iniciar sesión',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Ingresa tu celular y contraseña',
                    style:
                    TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                const SizedBox(height: 32),

                // Error banner
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                          const Color(0xFFFF3B30).withValues(alpha: 0.3)),
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

                // Celular
                _buildLabel('Número de celular'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _celularCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style:
                  const TextStyle(color: Colors.white, fontSize: 15),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu celular';
                    if (v.length != 9) return '9 dígitos requeridos';
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
                const SizedBox(height: 20),

                // Contraseña
                _buildLabel('Contraseña'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePassword,
                  style:
                  const TextStyle(color: Colors.white, fontSize: 15),
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Ingresa tu contraseña';
                    return null;
                  },
                  decoration: _inputDecoration(
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF6B7280),
                        size: 20,
                      ),
                      onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Olvidé contraseña
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ForgotPasswordView()),
                    ),
                    child: const Text('¿Olvidaste tu contraseña?',
                        style: TextStyle(
                            color: Color(0xFF1E6BFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 32),

                // Botón login
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
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
                        : const Text('Iniciar sesión',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 32),

                // Registro
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿No tienes cuenta? ',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterView()),
                      ),
                      child: const Text('Regístrate',
                          style: TextStyle(
                              color: Color(0xFF1E6BFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(
          color: Color(0xFFD1D5DB),
          fontSize: 13,
          fontWeight: FontWeight.w500));

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