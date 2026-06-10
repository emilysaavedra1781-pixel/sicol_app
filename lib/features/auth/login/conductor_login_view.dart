// ════════════════════════════════════════════════════════════════════════════
// RF23 — Inicio de Sesión del Conductor
// Archivo: lib/features/auth/login/conductor_login_view.dart
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../../services/auth_service.dart';
import '../../forgot_password/forgot_password_view.dart';
import '../../../conductor/conductor_home_view.dart';

class ConductorLoginView extends StatefulWidget {
  const ConductorLoginView({super.key});

  @override
  State<ConductorLoginView> createState() => _ConductorLoginViewState();
}

class _ConductorLoginViewState extends State<ConductorLoginView> {
  final _formKey    = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _authService = AuthService();

  bool   _loading          = false;
  bool   _obscurePassword  = true;
  String? _errorMessage;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Lógica de login (RF23) ────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading      = true;
      _errorMessage = null;
    });

    final result = await _authService.loginConductor(
      codigoConductor: _codigoCtrl.text.trim(),
      password: _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      // RF23 · Acceso concedido: navegar al panel del conductor
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConductorHomeView(
            uid:    result['uid']    as String,
            nombre: result['nombre'] as String,
          ),
        ),
      );
    } else {
      // RF23 · Manejo de errores
      setState(() {
        switch (result['error']) {
          case 'cuenta_bloqueada':
            // EA02 — RF40
            _errorMessage =
                'Tu cuenta está bloqueada. Usa "¿Olvidaste tu contraseña?" para desbloquearla.';
            break;

          case 'cuenta_inactiva':
            // Cuenta pendiente de aprobación (RF53/RF26)
            _errorMessage =
                'Tu cuenta aún no ha sido activada. Contacta al administrador.';
            break;

          case 'conductor_no_encontrado':
            _errorMessage =
                'No existe un conductor con ese código.';
            break;

          case 'error_servidor':
            _errorMessage =
                'Error al conectar con el servidor. Intenta más tarde.';
            break;

          default:
            // EA01 — credenciales incorrectas
            final intentos = result['intentosRestantes'];
            _errorMessage = intentos != null
                ? 'Código o contraseña incorrectos. Te quedan $intentos intento(s).'
                : 'Código o contraseña incorrectos.';
        }
      });
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
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

                // ── Branding ────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),   // verde conductor
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.drive_eta_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'SICOL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Panel del Conductor',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // ── Título ──────────────────────────────────────────────
                const Text(
                  'Iniciar sesión',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa tu código de conductor y contraseña',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                ),
                const SizedBox(height: 32),

                // ── Banner de error ─────────────────────────────────────
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFFF3B30), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFFF3B30),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Campo: código de conductor ──────────────────────────
                _buildLabel('Código de conductor'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _codigoCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu código de conductor';
                    return null;
                  },
                  decoration: _inputDecoration(
                    hint: 'Ej: COND-001',
                    icon: Icons.badge_outlined,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Campo: contraseña ───────────────────────────────────
                _buildLabel('Contraseña'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
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
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── ¿Olvidaste tu contraseña? (RF46) ───────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordView(),
                      ),
                    ),
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Botón login ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Nota: acceso exclusivo ──────────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFF6B7280), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Acceso exclusivo para conductores',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFD1D5DB),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF4B5563)),
        prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 20),
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
              const BorderSide(color: Color(0xFF10B981), width: 1.5),
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
