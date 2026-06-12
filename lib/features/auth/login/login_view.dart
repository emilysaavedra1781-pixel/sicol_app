import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/auth_service.dart';
import '../register/register_view.dart';
import '../forgot_password/forgot_password_view.dart';
import '../../passenger/passenger_home_view.dart';
import '../../driver/driver_pending_view.dart';
import '../../driver/driver_home_view.dart';
import '../../admin/admin_home_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _authService = AuthService();

  // Rol seleccionado: 'pasajero', 'conductor', 'admin'
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

  @override
  void dispose() {
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
      if (_celularCtrl.text.trim().isEmpty ||
          _passCtrl.text.isEmpty) {
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
      if (_codigoCtrl.text.trim().isEmpty ||
          _passCondCtrl.text.isEmpty) {
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
      if (_celularAdminCtrl.text.trim().isEmpty ||
          _passAdminCtrl.text.isEmpty) {
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
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
                    _rolTab('pasajero', 'Pasajero',
                        Icons.person_outline),
                    _rolTab('conductor', 'Conductor',
                        Icons.drive_eta_outlined),
                    _rolTab('admin', 'Admin',
                        Icons.admin_panel_settings_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Text('Iniciar sesión',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
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
                        color:
                        const Color(0xFFFF3B30).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFFF3B30), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                color: Color(0xFFFF3B30),
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              // Campos según rol
              if (_rolSeleccionado == 'pasajero')
                _buildPasajeroForm()
              else if (_rolSeleccionado == 'conductor')
                _buildConductorForm()
              else
                _buildAdminForm(),

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

              // Registro solo para pasajero y conductor
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
    );
  }

  Widget _buildPasajeroForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Número de celular'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _celularCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 15),
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
        _buildLabel('Contraseña'),
        const SizedBox(height: 8),
        _buildPassField(_passCtrl),
      ],
    );
  }

  Widget _buildConductorForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Código de conductor'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _codigoCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 2),
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
          ],
          onChanged: (value) {
            final upper = value.toUpperCase();
            if (value != upper) {
              _codigoCtrl.value = TextEditingValue(
                text: upper,
                selection: TextSelection.collapsed(offset: upper.length),
              );
            }
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa tu código de conductor';
            }
            if (value != value.trim()) {
              return 'No uses espacios al inicio o final';
            }
            if (!RegExp(r'^COND-\d{3}$').hasMatch(value)) {
              return 'Formato válido: COND-001';
            }
            return null;
          },
          decoration: _inputDecoration(hint: 'COND-001', icon: Icons.badge_outlined),
        ),
        const SizedBox(height: 20),
        _buildLabel('Contraseña'),
        const SizedBox(height: 8),
        _buildPassField(_passCondCtrl),  //
      ],
    );
  }

  Widget _buildAdminForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Número de celular'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _celularAdminCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 15),
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
        _buildLabel('Contraseña'),
        const SizedBox(height: 8),
        _buildPassField(_passAdminCtrl),
      ],
    );
  }

  Widget _buildPassField(TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      obscureText: _obscurePass,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
        if (value != value.trim()) return 'No uses espacios al inicio o final';
        if (value.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
        return null;
      },
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
          onPressed: () =>
              setState(() => _obscurePass = !_obscurePass),
        ),
      ),
    );
  }

  Widget _rolTab(String rol, String label, IconData icon) {
    final selected = _rolSeleccionado == rol;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _rolSeleccionado = rol;
          _errorMessage = null;
          _obscurePass = true;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1E6BFF)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF6B7280),
                  size: 20),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: selected
                          ? Colors.white
                          : const Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
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