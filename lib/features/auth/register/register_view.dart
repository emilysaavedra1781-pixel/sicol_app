import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/auth_service.dart';
import 'otp_verification_view.dart';

class RegisterView extends StatefulWidget {
  final String rolInicial;

  const RegisterView({super.key, this.rolInicial = 'pasajero'});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  late String _rolSeleccionado;

  // Datos personales
  final _dniCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _licenciaCtrl = TextEditingController();

  // Datos vehículo (conductor)
  final _placaCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _rolSeleccionado = widget.rolInicial;
  }

  @override
  void dispose() {
    _dniCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _celularCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fechaCtrl.dispose();
    _licenciaCtrl.dispose();
    _placaCtrl.dispose();
    _capacidadCtrl.dispose();
    _modeloCtrl.dispose();
    _marcaCtrl.dispose();
    _colorCtrl.dispose();
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

    final celular = _celularCtrl.text
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '');

    if (celular.length != 9 || !celular.startsWith('9')) {
      setState(() {
        _loading = false;
        _errorMessage = 'El número debe tener 9 dígitos y empezar con 9.';
      });
      return;
    }

    // Verificar duplicados
    final celularRegistrado = await _authService.isCelularRegistered(celular);
    if (!mounted) return;
    if (celularRegistrado) {
      setState(() {
        _loading = false;
        _errorMessage = 'Ya existe una cuenta con ese número de celular.';
      });
      return;
    }

    final dniRegistrado = await _authService.isDniRegistered(_dniCtrl.text.trim());
    if (!mounted) return;
    if (dniRegistrado) {
      setState(() {
        _loading = false;
        _errorMessage = 'Ya existe una cuenta con ese DNI.';
      });
      return;
    }

    if (_rolSeleccionado == 'conductor') {
      final placaRegistrada = await _authService
          .isPlacaRegistered(_placaCtrl.text.trim().toUpperCase());
      if (!mounted) return;
      if (placaRegistrada) {
        setState(() {
          _loading = false;
          _errorMessage = 'Ya existe una cuenta con esa placa.';
        });
        return;
      }
    }

    // MODO PRUEBA: saltar envío de OTP, ir directo a pantalla de verificación
    setState(() => _loading = false);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationView(
          verificationId: 'test-verification-id',
          phoneNumber: '+51$celular',
          userData: {
            'rol': _rolSeleccionado,
            'dni': _dniCtrl.text.trim(),
            'nombre': _nombreCtrl.text.trim(),
            'apellido': _apellidoCtrl.text.trim(),
            'celular': celular,
            'email': _emailCtrl.text.trim(),
            'password': _passCtrl.text,
            'fechaNacimiento': _fechaCtrl.text,
            if (_rolSeleccionado == 'conductor') ...{
              'numeroLicencia': _licenciaCtrl.text.trim(),
              'placa': _placaCtrl.text.trim().toUpperCase(),
              'capacidad': _capacidadCtrl.text.trim(),
              'modelo': _modeloCtrl.text.trim(),
              'marca': _marcaCtrl.text.trim(),
              'color': _colorCtrl.text.trim(),
            },
          },
        ),
      ),
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Crear cuenta',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ingresa tus datos',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  _errorBanner(_errorMessage!),
                  const SizedBox(height: 16),
                ],

                // Selector de rol
                _buildLabel('Tipo de cuenta'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Row(
                    children: [
                      _rolButton('pasajero', 'Pasajero', Icons.person_outline),
                      _rolButton('conductor', 'Conductor', Icons.drive_eta_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _seccionTitulo('Datos personales'),
                const SizedBox(height: 16),

                _buildLabel('DNI '),
                const SizedBox(height: 8),
                _buildField(
                  controller: _dniCtrl,
                  hint: '',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],

                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu documento';
                    if (v.length != 8) return 'El DNI debe tener 8 dígitos';
                    if (RegExp(r'^(\d)\1+$').hasMatch(v)) return 'DNI inválido';
                    if (v == '12345678' || v == '87654321') return 'DNI inválido';
                    return null;
                  },
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
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Requerido';
                              if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                              if (!RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$").hasMatch(v)) return 'Solo letras';
                              if (RegExp(r'^(.)\1+$').hasMatch(v.trim())) return 'Nombre inválido';
                              return null;
                            },
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
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Requerido';
                              if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                              if (!RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$").hasMatch(v)) return 'Solo letras';
                              if (RegExp(r'^(.)\1+$').hasMatch(v.trim())) return 'Nombre inválido';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildLabel('Número de celular'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _celularCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v.length != 9) return '9 dígitos exactos';
                    if (!v.startsWith('9')) return 'Debe empezar con 9';
                    if (RegExp(r'^(\d)\1+$').hasMatch(v)) return 'Número inválido';  // 999999999
                    if (v == '987654321' || v == '912345678') return 'Número inválido';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '9XXXXXXXX',
                    hintStyle: const TextStyle(color: Color(0xFF4B5563)),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 12, right: 4),
                      child: Text('+51 ',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 14)),
                    ),
                    prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),

                _buildLabel('Correo electrónico'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _emailCtrl,
                  hint: 'ejemplo@correo.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,4}$').hasMatch(v)) return 'Correo inválido';
                    final dominiosBloqueados = ['tempmail', 'mailinator', 'guerrillamail', 'yopmail'];
                    if (dominiosBloqueados.any((d) => v.toLowerCase().contains(d))) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildLabel('Fecha de nacimiento'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selectDate,
                  child: AbsorbPointer(
                    child: _buildField(
                      controller: _fechaCtrl,
                      hint: 'DD/MM/AAAA',
                      icon: Icons.calendar_today_outlined,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        try {
                          final parts = v.split('/');
                          final fecha = DateTime(
                            int.parse(parts[2]),
                            int.parse(parts[1]),
                            int.parse(parts[0]),
                          );
                          final hoy = DateTime.now();
                          final edad = hoy.year - fecha.year -
                              ((hoy.month < fecha.month ||
                                  (hoy.month == fecha.month && hoy.day < fecha.day)) ? 1 : 0);
                          if (edad < 18) return 'Debes ser mayor de 18 años';
                          if (edad > 100) return 'Fecha inválida';
                        } catch (_) {
                          return 'Fecha inválida';
                        }
                        return null;
                      },

                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_rolSeleccionado == 'conductor') ...[
                  _buildLabel('Número de licencia'),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _licenciaCtrl,
                    hint: 'Q12345678',
                    icon: Icons.card_membership_outlined,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (!RegExp(r'^[A-Za-z]\d{8}$').hasMatch(v)) return 'Formato: Q12345678';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

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
                    if (RegExp(r'^(.)\1+$').hasMatch(v)) return 'Contraseña muy débil';
                    if (['123456', '654321', 'password', '000000'].contains(v)) return 'Contraseña muy débil';
                    return null;
                  },
                ),

                if (_rolSeleccionado == 'conductor') ...[
                  const SizedBox(height: 24),
                  _seccionTitulo('Datos del vehículo'),
                  const SizedBox(height: 16),

                  _buildLabel('Placa'),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _placaCtrl,
                    hint: 'ABC-123',
                    icon: Icons.directions_car_outlined,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (!RegExp(r'^[A-Za-z]{3}-?\d{3}$').hasMatch(v)) return 'Formato: ABC-123';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Marca'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _marcaCtrl,
                              hint: 'Toyota',
                              icon: Icons.directions_car_outlined,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requerido';
                                if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                                if (!RegExp(r'^[a-zA-ZÀ-ÿ\s\-]+$').hasMatch(v.trim())) {
                                  return 'Solo letras';
                                }
                                return null;
                              },

                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Modelo'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _modeloCtrl,
                              hint: 'Corolla',
                              icon: Icons.directions_car_outlined,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requerido';
                                if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                                if (!RegExp(r'^[a-zA-Z0-9À-ÿ\s\-]+$').hasMatch(v.trim())) {
                                  return 'Formato inválido';
                                }
                                return null;
                              },

                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

    Row(
    children: [
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    _buildLabel('Color'),
    const SizedBox(height: 8),
    _buildField(
    controller: _colorCtrl,
    hint: 'Blanco',
    icon: Icons.color_lens_outlined,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Requerido';
        if (!RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$").hasMatch(v)) return 'Solo letras';
        if (v.trim().length < 3) return 'Mínimo 3 caracteres';
        return null;
      },
    ),
    ],
    ),
    ),
    const SizedBox(width: 12),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    _buildLabel('Capacidad'),
    const SizedBox(height: 8),
    DropdownButtonFormField<String>(
    value: _capacidadCtrl.text.isEmpty ? null : _capacidadCtrl.text,
    dropdownColor: const Color(0xFF111827),
    style: const TextStyle(color: Colors.white, fontSize: 15),
    decoration: InputDecoration(
    prefixIcon: const Icon(Icons.people_outline,
    color: Color(0xFF6B7280), size: 20),
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
    borderSide: const BorderSide(color: Color(0xFF1E6BFF), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFFF3B30)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    errorStyle: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
    ),
    hint: const Text('Seleccionar',
    style: TextStyle(color: Color(0xFF4B5563))),
    items: ['4', '5', '6', '7', '8', '15']
        .map((e) => DropdownMenuItem(
    value: e,
    child: Text('$e asientos'),
    ))
        .toList(),
    onChanged: (v) => setState(() => _capacidadCtrl.text = v ?? ''),
    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
    ),
    ],
    ),
    ),
    ],
    ),
                ],



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
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                        : const Text('Continuar y verificar',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _seccionTitulo(String texto) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF1E6BFF).withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border:
      Border.all(color: const Color(0xFF1E6BFF).withOpacity(0.3)),
    ),
    child: Text(texto,
        style: const TextStyle(
            color: Color(0xFF1E6BFF),
            fontSize: 13,
            fontWeight: FontWeight.w600)),
  );

  Widget _rolButton(String rol, String label, IconData icon) {
    final selected = _rolSeleccionado == rol;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _rolSeleccionado = rol;
          _errorMessage = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1E6BFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: selected ? Colors.white : const Color(0xFF6B7280),
                  size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color:
                      selected ? Colors.white : const Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
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
      border: Border.all(
          color: const Color(0xFFFF3B30).withOpacity(0.3)),
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

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(
          color: Color(0xFFD1D5DB),
          fontSize: 13,
          fontWeight: FontWeight.w500));

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    Widget? prefix,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF4B5563)),
        prefixIcon: prefix ??
            Icon(icon, color: const Color(0xFF6B7280), size: 20),
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