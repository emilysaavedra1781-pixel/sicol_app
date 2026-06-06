import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth_service.dart';
import 'otp_verification_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _dniCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;
  String? _errorMessage;

  @override
  void dispose() {
    _dniCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _celularCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF1E6BFF),
            surface: Color(0xFF111827),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _fechaCtrl.text =
      '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    // Limpiar sesión huérfana primero
    await _authService.limpiarSesionHuerfana();

    // EA02: Verificar si el celular ya está registrado
    final celular = _celularCtrl.text.trim();
    final yaRegistrado = await _authService.isCelularRegistered(celular);

    if (!mounted) return;

    if (yaRegistrado) {
      setState(() {
        _loading = false;
        _errorMessage =
        'Ya existe una cuenta con ese número de celular.';
      });
      return;
    }

    // Enviar OTP (RF01 paso 5)
    final phoneNumber = '+51$celular';
    String? verificationId;

    await _authService.sendOTP(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verificado en Android
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorMessage =
            'Error al enviar OTP. Verifica el número de celular.';
          });
        }
      },
      codeSent: (String vId, int? resendToken) {
        verificationId = vId;
        if (mounted) {
          setState(() => _loading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationView(
                verificationId: verificationId!,
                phoneNumber: phoneNumber,
                userData: {
                  'dni': _dniCtrl.text.trim(),
                  'nombre': _nombreCtrl.text.trim(),
                  'apellido': _apellidoCtrl.text.trim(),
                  'celular': celular,
                  'email': _emailCtrl.text.trim(),
                  'password': _passCtrl.text,
                  'fechaNacimiento': _fechaCtrl.text,
                },
              ),
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (String vId) {
        verificationId = vId;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Crear cuenta',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingresa tus datos',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  _errorBanner(_errorMessage!),
                  const SizedBox(height: 16),
                ],

                // DNI
                _buildLabel('DNI / Pasaporte / Carnet'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _dniCtrl,
                  hint: '12345678',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty
                      ? 'Ingresa tu documento'
                      : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Nombre'),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: _nombreCtrl,
                            hint: 'Juan',
                            icon: Icons.person_outline,
                            validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Apellido'),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: _apellidoCtrl,
                            hint: 'Pérez',
                            icon: Icons.person_outline,
                            validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Celular
                _buildLabel('Número de celular'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _celularCtrl,
                  hint: '9XXXXXXXX',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 4),
                    child: Text('+51 ',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 14)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v.length != 9) return '9 dígitos';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                _buildLabel('Correo electrónico'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _emailCtrl,
                  hint: 'ejemplo@correo.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (!v.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Fecha de nacimiento
                _buildLabel('Fecha de nacimiento'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selectDate,
                  child: AbsorbPointer(
                    child: _buildField(
                      controller: _fechaCtrl,
                      hint: 'DD/MM/AAAA',
                      icon: Icons.calendar_today_outlined,
                      validator: (v) =>
                      v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Contraseña
                _buildLabel('Contraseña'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _passCtrl,
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  obscure: _obscurePass,
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
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6BFF),
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
                          color: Colors.white, strokeWidth: 2.5),
                    )
                        : const Text(
                      'Continuar y verificar',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String msg) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFF3B30).withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border:
      Border.all(color: const Color(0xFFFF3B30).withOpacity(0.3)),
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

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFFD1D5DB),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    Widget? prefix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
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
      ),
    );
  }
}
