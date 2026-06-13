import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_widgets.dart';

class PasajeroForm extends StatelessWidget {
  final TextEditingController celularCtrl;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final VoidCallback onTogglePass;

  const PasajeroForm({
    super.key,
    required this.celularCtrl,
    required this.passCtrl,
    required this.obscurePass,
    required this.onTogglePass,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLabel('Número de celular'),
        const SizedBox(height: 8),
        TextFormField(
          controller: celularCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: inputDecoration(
            hint: '9XXXXXXXX',
            icon: Icons.phone_outlined,
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12, right: 4),
              child: Text(
                '+51 ',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        buildLabel('Contraseña'),
        const SizedBox(height: 8),
        buildPassField(
          ctrl: passCtrl,
          obscure: obscurePass,
          onToggle: onTogglePass,
        ),
      ],
    );
  }
}

class ConductorForm extends StatelessWidget {
  final TextEditingController codigoCtrl;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final VoidCallback onTogglePass;

  const ConductorForm({
    super.key,
    required this.codigoCtrl,
    required this.passCtrl,
    required this.obscurePass,
    required this.onTogglePass,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLabel('Código de conductor'),
        const SizedBox(height: 9),
        TextFormField(
          controller: codigoCtrl,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            letterSpacing: 2,
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 9,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
          ],
          onChanged: (value) {
            final upper = value.toUpperCase();
            if (value != upper) {
              codigoCtrl.value = TextEditingValue(
                text: upper,
                selection: TextSelection.collapsed(offset: upper.length),
              );
            }
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa tu código de conductor';
            }
            if (value != value.trim()) return 'No uses espacios al inicio o final';
            if (!RegExp(r'^COND-\d{3}$').hasMatch(value)) {
              return 'Formato válido: COND-0001';
            }
            return null;
          },
          decoration: inputDecoration(hint: 'COND-0001', icon: Icons.badge_outlined),
        ),
        const SizedBox(height: 20),
        buildLabel('Contraseña'),
        const SizedBox(height: 9),
        buildPassField(
          ctrl: passCtrl,
          obscure: obscurePass,
          onToggle: onTogglePass,
        ),
      ],
    );
  }
}

class AdminForm extends StatelessWidget {
  final TextEditingController celularCtrl;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final VoidCallback onTogglePass;

  const AdminForm({
    super.key,
    required this.celularCtrl,
    required this.passCtrl,
    required this.obscurePass,
    required this.onTogglePass,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLabel('Número de celular'),
        const SizedBox(height: 8),
        TextFormField(
          controller: celularCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: inputDecoration(
            hint: '9XXXXXXXX',
            icon: Icons.phone_outlined,
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12, right: 4),
              child: Text(
                '+51 ',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        buildLabel('Contraseña'),
        const SizedBox(height: 8),
        buildPassField(
          ctrl: passCtrl,
          obscure: obscurePass,
          onToggle: onTogglePass,
        ),
      ],
    );
  }
}