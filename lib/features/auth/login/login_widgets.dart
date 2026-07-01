import 'package:flutter/material.dart';

Widget buildLabel(String text) => Padding(
  padding: const EdgeInsets.only(left: 4),
  child: Text(
    text,
    style: const TextStyle(
      color: Color(0xFF6B7280),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  ),
);

Widget buildPassField({
  required TextEditingController ctrl,
  required bool obscure,
  required VoidCallback onToggle,
  String? errorText,
}) {
  return TextFormField(
    controller: ctrl,
    obscureText: obscure,
    style: const TextStyle(color: Color(0xFF111827), fontSize: 15),
    decoration: inputDecoration(
      hint: '••••••••',
      icon: Icons.lock_outline,
      errorText: errorText,
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

InputDecoration inputDecoration({
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
  Widget? prefix,
  String? errorText,
}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      prefixIcon: prefix ?? Icon(icon, color: const Color(0xFF6B7280), size: 20),
      suffixIcon: suffixIcon,
      errorText: errorText,
      errorStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6B21F5), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
