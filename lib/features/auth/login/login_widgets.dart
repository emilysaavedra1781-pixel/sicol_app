import 'package:flutter/material.dart';

/// Pestaña de selección de rol
Widget rolTab({
  required String rol,
  required String rolSeleccionado,
  required String label,
  required IconData icon,
  required VoidCallback onTap,
}) {
  final selected = rolSeleccionado == rol;
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E6BFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF6B7280),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Label de campo de formulario
Widget buildLabel(String text) => Text(
  text,
  style: const TextStyle(
    color: Color(0xFFD1D5DB),
    fontSize: 13,
    fontWeight: FontWeight.w500,
  ),
);

/// Campo de contraseña con toggle de visibilidad
Widget buildPassField({
  required TextEditingController ctrl,
  required bool obscure,
  required VoidCallback onToggle,
}) {
  return TextFormField(
    controller: ctrl,
    obscureText: obscure,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    validator: (value) {
      if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
      if (value != value.trim()) return 'No uses espacios al inicio o final';
      if (value.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
      return null;
    },
    decoration: inputDecoration(
      hint: '••••••••',
      icon: Icons.lock_outline,
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: const Color(0xFF6B7280),
          size: 20,
        ),
        onPressed: onToggle,
      ),
    ),
  );
}

/// Decoración estándar para inputs
InputDecoration inputDecoration({
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
  Widget? prefix,
}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF4B5563)),
      prefixIcon: prefix ?? Icon(icon, color: const Color(0xFF6B7280), size: 20),
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
        borderSide: const BorderSide(color: Color(0xFF1E6BFF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF3B30)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );