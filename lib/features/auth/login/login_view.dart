import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../register/register_view.dart';
import '../forgot_password/forgot_password_view.dart';
import '../../passenger/passenger_home_view.dart';
import '../../driver/driver_pending_view.dart';
import '../../driver/driver_home_view.dart';
import '../../admin/admin_home_view.dart';
import 'login_form.dart';
import '../../../app_theme.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _authService = AuthService();

  String _rolSeleccionado = 'pasajero';

  // Pasajero
  final _celularCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _pasajeroCelularError;
  String? _pasajeroPassError;

  // Conductor
  final _codigoCtrl = TextEditingController();
  final _passCondCtrl = TextEditingController();

  // Admin
  final _celularAdminCtrl = TextEditingController();
  final _passAdminCtrl = TextEditingController();
  String? _adminCelularError;
  String? _adminPassError;

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sesión expirada',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Tu sesión cerró por inactividad. Vuelve a iniciar sesión.',
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
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

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

    try {
      Map<String, dynamic> result;

      if (_rolSeleccionado == 'pasajero') {
        bool hasError = false;
        setState(() {
          _pasajeroCelularError = null;
          _pasajeroPassError = null;
        });

        if (_celularCtrl.text.trim().isEmpty) {
          setState(() => _pasajeroCelularError = 'El celular es obligatorio');
          hasError = true;
        }
        if (_passCtrl.text.isEmpty) {
          setState(() => _pasajeroPassError = 'La contraseña es obligatoria');
          hasError = true;
        }

        if (hasError) {
          setState(() => _loading = false);
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
        bool hasError = false;
        setState(() {
          _adminCelularError = null;
          _adminPassError = null;
        });

        if (_celularAdminCtrl.text.trim().isEmpty) {
          setState(() => _adminCelularError = 'El usuario es obligatorio');
          hasError = true;
        }
        if (_passAdminCtrl.text.isEmpty) {
          setState(() => _adminPassError = 'La contraseña es obligatoria');
          hasError = true;
        }

        if (hasError) {
          setState(() => _loading = false);
          return;
        }

        result = await _authService.loginAdmin(
          celular: _celularAdminCtrl.text.trim(),
          password: _passAdminCtrl.text,
        );
      }

      if (!mounted) return;

      if (result['success'] == true) {
        _resetSessionTimer();
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
            _errorMessage = 'Tu cuenta ha sido bloqueada. Usa la opción de recuperación de contraseña para desbloquearla.';
            break;
          case 'cuenta_pendiente':
              _errorMessage = 'Tu cuenta está pendiente de aprobación. No puedes realizar operaciones hasta que el administrador apruebe tu solicitud.';
              break;
            case 'cuenta_rechazada':
              _errorMessage = 'Tu cuenta fue rechazada.';
              break;
            case 'usuario_no_encontrado':
              _errorMessage = 'Esta cuenta no existe o no está registrada.'; // CP03
              break;
            case 'credenciales_invalidas':
              _errorMessage = 'Credenciales incorrectas.'; // CP02
              break;
            default:
              _errorMessage = 'Credenciales incorrectas.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudo conectar. Verifica tu conexión a internet e inténtalo de nuevo.'; // CP05
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetSessionTimer(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: const Icon(Icons.directions_bus_rounded,
                            color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 24),
                      Text('SICOL',
                          style: Theme.of(context).textTheme.displayLarge),
                      const SizedBox(height: 8),
                      Text('Sistema de Colectivos',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildRolTab('pasajero', 'Pasajero'),
                      _buildRolTab('conductor', 'Conductor'),
                      _buildRolTab('admin', 'Admin'),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text('Bienvenido',
                    style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 8),
                Text(
                  _rolSeleccionado == 'conductor'
                      ? 'Ingresa tu código de conductor y contraseña'
                      : 'Ingresa tu celular y contraseña',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Theme.of(context).colorScheme.error, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_errorMessage!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                if (_rolSeleccionado == 'pasajero')
                  PasajeroForm(
                    celularCtrl: _celularCtrl,
                    passCtrl: _passCtrl,
                    obscurePass: _obscurePass,
                    celularError: _pasajeroCelularError,
                    passError: _pasajeroPassError,
                    onTogglePass: () => setState(() => _obscurePass = !_obscurePass),
                  )
                else if (_rolSeleccionado == 'conductor')
                  ConductorForm(
                    codigoCtrl: _codigoCtrl,
                    passCtrl: _passCondCtrl,
                    obscurePass: _obscurePass,
                    onTogglePass: () => setState(() => _obscurePass = !_obscurePass),
                  )
                else
                  AdminForm(
                    celularCtrl: _celularAdminCtrl,
                    passCtrl: _passAdminCtrl,
                    obscurePass: _obscurePass,
                    celularError: _adminCelularError,
                    passError: _adminPassError,
                    onTogglePass: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordView()),
                    ),
                    child: Text('¿Olvidaste tu contraseña?',
                        style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('INICIAR SESIÓN'),
                ),
                const SizedBox(height: 32),
                if (_rolSeleccionado != 'admin')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('¿No tienes cuenta? ',
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RegisterView(rolInicial: _rolSeleccionado)),
                        ),
                        child: Text('Regístrate',
                            style: TextStyle(
                                color: Theme.of(context).primaryColor,
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

  Widget _buildRolTab(String rol, String label) {
    final seleccionado = _rolSeleccionado == rol;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _rolSeleccionado = rol;
          _errorMessage = null;
          _adminCelularError = null;
          _adminPassError = null;
          _obscurePass = true;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: seleccionado ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: seleccionado
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: seleccionado ? CabifyColors.primary : CabifyColors.textSecondary,
              fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
