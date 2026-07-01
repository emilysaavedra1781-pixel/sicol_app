import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../services/auth_service.dart';
import 'otp_verification_view.dart';
import '../../../app_theme.dart';

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

  File? _fotoPerfil;
  File? _fotoVehiculo;
  final _picker = ImagePicker();

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
      builder: (context, child) =>
          Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: CabifyColors.primary,
              ),
            ),
            child: child!,
          ),
    );
    if (picked != null) {
      _fechaCtrl.text =
      '${picked.day.toString().padLeft(2, '0')}/${picked.month
          .toString()
          .padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _pickImage(bool esVehiculo) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        if (esVehiculo) {
          _fotoVehiculo = File(pickedFile.path);
        } else {
          _fotoPerfil = File(pickedFile.path);
        }
      });
    }
  }

  Widget _buildPhotoSelector(String label, File? image, bool esVehiculo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickImage(esVehiculo),
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(image, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: Theme.of(context).primaryColor),
                      const SizedBox(height: 4),
                      const Text('Toca para subir foto', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
          ),
        ),
      ],
    );
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
    try {
      final celularRegistrado = await _authService.isCelularRegistered(celular);
      if (!mounted) return;
      if (celularRegistrado) {
        setState(() {
          _loading = false;
          _errorMessage = 'Este número de celular ya tiene una cuenta registrada.';
        });
        return;
      }

      final dniRegistrado = await _authService.isDniRegistered(_dniCtrl.text.trim());
      if (!mounted) return;
      if (dniRegistrado) {
        setState(() {
          _loading = false;
          _errorMessage = 'Este DNI ya tiene una cuenta registrada.';
        });
        return;
      }

      if (_rolSeleccionado == 'conductor') {
        // CP02 - Foto obligatoria
        if (_fotoPerfil == null) {
          setState(() {
            _loading = false;
            _errorMessage = 'La fotografía es obligatoria para completar el registro.';
          });
          return;
        }

        final placaRegistrada = await _authService.isPlacaRegistered(_placaCtrl.text.trim().toUpperCase());
        if (!mounted) return;
        if (placaRegistrada) {
          setState(() {
            _loading = false;
            _errorMessage = 'La placa del vehículo ya está registrada en el sistema.';
          });
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'No se pudo conectar. Verifica tu conexión a internet e inténtalo de nuevo.';
        });
      }
      return;
    }

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
              'fotoPerfil': _fotoPerfil,
              'fotoVehiculo': _fotoVehiculo,
            },
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ingresa tus datos para empezar',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                const SizedBox(height: 32),

                if (_errorMessage != null) ...[
                  _errorBanner(_errorMessage!),
                  const SizedBox(height: 16),
                ],

                _buildLabel('TIPO DE CUENTA'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _rolButton('pasajero', 'Pasajero', Icons.person_outline),
                      _rolButton('conductor', 'Conductor', Icons.drive_eta_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                _seccionTitulo('DATOS PERSONALES'),
                const SizedBox(height: 20),

                _buildLabel('DNI'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _dniCtrl,
                  hint: '8 dígitos',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  validator: (v) => (v == null || v.length != 8) ? 'Ingresa 8 dígitos' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('NOMBRE'),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: _nombreCtrl,
                            hint: 'Ej. Juan',
                            icon: Icons.person_outline,
                            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('APELLIDO'),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: _apellidoCtrl,
                            hint: 'Ej. Pérez',
                            icon: Icons.person_outline,
                            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildLabel('CELULAR'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _celularCtrl,
                  hint: '9XXXXXXXX',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 4),
                    child: Text('+51 ', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold)),
                  ),
                  validator: (v) => (v == null || v.length != 9) ? '9 dígitos' : null,
                ),
                const SizedBox(height: 16),

                _buildLabel('CORREO ELECTRÓNICO'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _emailCtrl,
                  hint: 'usuario@email.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email inválido' : null,
                ),
                const SizedBox(height: 16),

                _buildLabel('FECHA DE NACIMIENTO'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selectDate,
                  child: AbsorbPointer(
                    child: _buildField(
                      controller: _fechaCtrl,
                      hint: 'DD/MM/AAAA',
                      icon: Icons.calendar_today_outlined,
                      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (_rolSeleccionado == 'conductor') ...[
                  _seccionTitulo('DATOS DEL CONDUCTOR'),
                  const SizedBox(height: 20),
                  
                  _buildPhotoSelector('FOTO DE PERFIL', _fotoPerfil, false),
                  const SizedBox(height: 16),
                  _buildPhotoSelector('FOTO DEL VEHÍCULO', _fotoVehiculo, true),
                  const SizedBox(height: 16),

                  _buildLabel('NÚMERO DE LICENCIA'),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _licenciaCtrl,
                    hint: 'Q12345678',
                    icon: Icons.card_membership_outlined,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      // CP06 - Formato licencia (1 letra + 8 dígitos)
                      if (!RegExp(r'^[A-Z]\d{8}$').hasMatch(v)) {
                        return 'Formato inválido (Ej. Q12345678)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('PLACA'),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _placaCtrl,
                    hint: 'ABC-123',
                    icon: Icons.directions_car_outlined,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('CAPACIDAD DE ASIENTOS'),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _capacidadCtrl,
                    hint: '4',
                    icon: Icons.event_seat_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('MARCA'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _marcaCtrl,
                              hint: 'Toyota',
                              icon: Icons.directions_car,
                              validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('MODELO'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _modeloCtrl,
                              hint: 'Corolla',
                              icon: Icons.directions_car,
                              validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('COLOR'),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _colorCtrl,
                    hint: 'Blanco',
                    icon: Icons.palette_outlined,
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                _buildLabel('CONTRASEÑA'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _passCtrl,
                  hint: 'Mínimo 8 caracteres',
                  icon: Icons.lock_outline,
                  obscure: _obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF6B7280), size: 20),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                  validator: (v) => (v == null || v.length < 8) ? 'Contraseña muy corta' : null,
                ),

                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('CONTINUAR Y VERIFICAR'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _seccionTitulo(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(texto, style: const TextStyle(color: CabifyColors.primary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
  );

  Widget _rolButton(String rol, String label, IconData icon) {
    final selected = _rolSeleccionado == rol;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _rolSeleccionado = rol; _errorMessage = null; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? CabifyColors.primary : CabifyColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: selected ? CabifyColors.primary : CabifyColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))),
      ],
    ),
  );

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );

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
      style: const TextStyle(color: Color(0xFF111827), fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix ?? Icon(icon, color: const Color(0xFF6B7280), size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
