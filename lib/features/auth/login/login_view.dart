import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/notification_service.dart';
import '../register/register_view.dart';
import '../forgot_password/forgot_password_view.dart';
import '../../passenger/passenger_home_view.dart';
import '../../driver/driver_pending_view.dart';
import '../../driver/driver_home_view.dart';
import '../../admin/admin_home_view.dart';
import 'login_form.dart';
import 'login_widgets.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _authService = AuthService();
  final _notificationService = NotificationService();

  String _rolSeleccionado = 'pasajero';

  // Pasajero
  final _celularCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // Conductor
  final _codigoCtrl = TextEditingController();
  final _passCondCtrl = TextEditingController();

  // Admin
  final _celularAdminCtrl = TextEditingController();
  final _passAdminCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;
  String? _errorMessage;

  // ── Session timeout ──────────────────────────────────────
  static const Duration _sessionTimeout = Duration(hours: 2, minutes: 30);
  Timer? _sessionTimer;

  void _resetSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(_sessionTimeout, _onSessionExpired);
  }

  void _onSessionExpired() {
    if (!mounted) return;
    // Muestra aviso y regresa al login
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sesión expirada',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Tu sesión cerró por inactividad. Vuelve a iniciar sesión.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginView()),
                    (route) => false,
              );
            },
            child: const Text('Aceptar',
                style: TextStyle(color: Color(0xFF1E6BFF))),
          ),
        ],
      ),
    );
  }
  // ────────────────────────────────────────────────────────

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _celularCtrl.dispose();
    _passCtrl.dispose();
    _codigoCtrl.dispose();
    _passCondCtrl.dispose();
    _celularAdminCtrl.dispose();
    _passAdminCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    Map<String, dynamic> result;

    if (_rolSeleccionado == 'pasajero') {
      if (_celularCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = 'Completa todos los campos.';
        });
        return;
      }
      result = await _authService.loginWithCelular(
        celular: _celularCtrl.text.trim(),
        password: _passCtrl.text,
      );
    } else if (_rolSeleccionado == 'conductor') {
      if (_codigoCtrl.text.trim().isEmpty || _passCondCtrl.text.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = 'Completa todos los campos.';
        });
        return;
      }
      result = await _authService.loginConductor(
        codigoConductor: _codigoCtrl.text.trim().toUpperCase(),
        password: _passCondCtrl.text,
      );
    } else {
      if (_celularAdminCtrl.text.trim().isEmpty || _passAdminCtrl.text.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = 'Completa todos los campos.';
        });
        return;
      }
      result = await _authService.loginAdmin(
        celular: _celularAdminCtrl.text.trim(),
        password: _passAdminCtrl.text,
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      // Inicia el timer de sesión al loguearse
      _resetSessionTimer();

      // RF30/RF42 — Registrar token FCM para notificaciones push
      await _notificationService.registrarToken();

      final rol = result['rol'];
      final estado = result['estado'] ?? 'activo';

      Widget destino;
      if (rol == 'admin') {
        destino = const AdminHomeView();
      } else if (rol == 'conductor') {
        destino = estado == 'activo'
            ? const DriverHomeView()
            : const DriverPendingView();
      } else {
        destino = const PassengerHomeView();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destino),
      );
    } else {
      setState(() {
        switch (result['error']) {
          case 'cuenta_bloqueada':
            _errorMessage =
            'Tu cuenta está bloqueada. Usa "¿Olvidaste tu contraseña?" para desbloquearla.';
            break;
          case 'cuenta_pendiente':
            _errorMessage =
            'Tu cuenta está pendiente de aprobación. Espera la confirmación del administrador.';
            break;
          case 'cuenta_rechazada':
            _errorMessage =
            'Tu cuenta fue rechazada. Contacta al administrador.';
            break;
          case 'usuario_no_encontrado':
            _errorMessage = 'No existe una cuenta con esos datos.';
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
    return Listener(
      // Reinicia el timer con cualquier toque del usuario
      onPointerDown: (_) => _resetSessionTimer(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
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
                const SizedBox(height: 40),

                // Selector de rol
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Row(
                    children: [
                      rolTab(
                        rol: 'pasajero',
                        rolSeleccionado: _rolSeleccionado,
                        label: 'Pasajero',
                        icon: Icons.person_outline,
                        onTap: () => setState(() {
                          _rolSeleccionado = 'pasajero';
                          _errorMessage = null;
                          _obscurePass = true;
                        }),
                      ),
                      rolTab(
                        rol: 'conductor',
                        rolSeleccionado: _rolSeleccionado,
                        label: 'Conductor',
                        icon: Icons.drive_eta_outlined,
                        onTap: () => setState(() {
                          _rolSeleccionado = 'conductor';
                          _errorMessage = null;
                          _obscurePass = true;
                        }),
                      ),
                      rolTab(
                        rol: 'admin',
                        rolSeleccionado: _rolSeleccionado,
                        label: 'Admin',
                        icon: Icons.admin_panel_settings_outlined,
                        onTap: () => setState(() {
                          _rolSeleccionado = 'admin';
                          _errorMessage = null;
                          _obscurePass = true;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                const Text('Iniciar sesión',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 9),
                Text(
                  _rolSeleccionado == 'conductor'
                      ? 'Ingresa tu código de conductor y contraseña'
                      : 'Ingresa tu celular y contraseña',
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 14),
                ),
                const SizedBox(height: 32),

                // Error banner
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFFF3B30).withOpacity(0.3)),
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

                // Formulario según rol
                if (_rolSeleccionado == 'pasajero')
                  PasajeroForm(
                    celularCtrl: _celularCtrl,
                    passCtrl: _passCtrl,
                    obscurePass: _obscurePass,
                    onTogglePass: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  )
                else if (_rolSeleccionado == 'conductor')
                  ConductorForm(
                    codigoCtrl: _codigoCtrl,
                    passCtrl: _passCondCtrl,
                    obscurePass: _obscurePass,
                    onTogglePass: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  )
                else
                  AdminForm(
                    celularCtrl: _celularAdminCtrl,
                    passCtrl: _passAdminCtrl,
                    obscurePass: _obscurePass,
                    onTogglePass: () =>
                        setState(() => _obscurePass = !_obscurePass),
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
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 32),

                // Registro
                if (_rolSeleccionado != 'admin')
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
                              builder: (_) => RegisterView(
                                  rolInicial: _rolSeleccionado)),
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
}