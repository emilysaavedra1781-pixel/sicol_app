import 'package:flutter/material.dart';

Widget legendItem(Color color, String label) {
  return Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
    ],
  );
}