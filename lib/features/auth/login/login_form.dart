import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_widgets.dart';

class PasajeroForm extends StatelessWidget {
  final TextEditingController celularCtrl;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final String? celularError;
  final String? passError;
  final VoidCallback onTogglePass;

  const PasajeroForm({
    super.key,
    required this.celularCtrl,
    required this.passCtrl,
    required this.obscurePass,
    this.celularError,
    this.passError,
    required this.onTogglePass,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLabel('NÚMERO DE CELULAR'),
        const SizedBox(height: 8),
        TextFormField(
          controller: celularCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Color(0xFF111827), fontSize: 15),
          decoration: inputDecoration(
            hint: '9XXXXXXXX',
            icon: Icons.phone_outlined,
            errorText: celularError,
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12, right: 4),
              child: Text(
                '+51 ',
                style: TextStyle(color: Color(0xFF111827), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        buildLabel('CONTRASEÑA'),
        const SizedBox(height: 8),
        buildPassField(
          ctrl: passCtrl,
          obscure: obscurePass,
          errorText: passError,
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
        buildLabel('CÓDIGO DE CONDUCTOR'),
        const SizedBox(height: 8),
        TextFormField(
          controller: codigoCtrl,
          style: const TextStyle(color: Color(0xFF111827), fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2),
          textCapitalization: TextCapitalization.characters,
          decoration: inputDecoration(hint: 'COND-0001', icon: Icons.badge_outlined),
        ),
        const SizedBox(height: 20),
        buildLabel('CONTRASEÑA'),
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

class AdminForm extends StatelessWidget {
  final TextEditingController celularCtrl;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final String? celularError;
  final String? passError;
  final VoidCallback onTogglePass;

  const AdminForm({
    super.key,
    required this.celularCtrl,
    required this.passCtrl,
    required this.obscurePass,
    this.celularError,
    this.passError,
    required this.onTogglePass,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLabel('NÚMERO DE CELULAR'),
        const SizedBox(height: 8),
        TextFormField(
          controller: celularCtrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Color(0xFF111827), fontSize: 15),
          decoration: inputDecoration(
            hint: '9XXXXXXXX',
            icon: Icons.phone_outlined,
            errorText: celularError,
          ),
        ),
        const SizedBox(height: 20),
        buildLabel('CONTRASEÑA'),
        const SizedBox(height: 8),
        buildPassField(
          ctrl: passCtrl,
          obscure: obscurePass,
          errorText: passError,
          onToggle: onTogglePass,
        ),
      ],
    );
  }
}
