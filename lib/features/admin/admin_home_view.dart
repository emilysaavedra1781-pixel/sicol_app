import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../auth/login/login_view.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/conductores_tab.dart';
import 'tabs/usuarios_tab.dart';
import 'tabs/viajes_tab.dart';
import 'tabs/paraderos_tab.dart';

class AdminHomeView extends StatefulWidget {
  const AdminHomeView({super.key});

  @override
  State<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<AdminHomeView> {
  final _authService = AuthService();
  final _db = FirebaseFirestore.instance;
  int _tabIndex = 0;

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _authService.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginView()),
            (r) => false,
      );
    }
  }

  Future<void> _aprobar(String uid, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Aprobar conductor', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Aprobar la cuenta de $nombre después de validar físicamente sus documentos?',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aprobar', style: TextStyle(color: Color(0xFF10B981))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final codigo = await _authService.aprobarConductor(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $nombre aprobado. Código: $codigo'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _rechazar(String uid, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rechazar conductor', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Rechazar la cuenta de $nombre?',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _authService.rechazarConductor(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Cuenta de $nombre rechazada.'),
        backgroundColor: const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // RF21: Bloqueo con motivo obligatorio / Desbloqueo directo
  Future<void> _toggleUsuario(String uid, String nombre, bool bloqueado) async {
    final txtMotivo = TextEditingController();
    final formKey = GlobalKey<FormState>();

    if (!bloqueado) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Bloquear cuenta de $nombre',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Es obligatorio registrar el motivo de la sanción para auditoría del sistema.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: txtMotivo,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Motivo del bloqueo',
                    labelStyle: TextStyle(color: Color(0xFF6B7280)),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF1F2937))),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF1E6BFF))),
                  ),
                  validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Ingrese un motivo válido' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Confirmar Bloqueo',
                  style: TextStyle(color: Color(0xFFFF3B30))),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _db.collection('usuarios').doc(uid).update({
          'estado': 'bloqueado',
          'motivoBloqueo': txtMotivo.text.trim(),
          'fechaBloqueo': FieldValue.serverTimestamp(),
        });
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Habilitar usuario', style: TextStyle(color: Colors.white)),
          content: Text(
            '¿Deseas restaurar el acceso activo para $nombre?',
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reactivar', style: TextStyle(color: Color(0xFF10B981))),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _db.collection('usuarios').doc(uid).update({
          'estado': 'activo',
          'motivoBloqueo': FieldValue.delete(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'SICOL — Sistema de Control',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF6B7280)),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF111827),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tab(0, Icons.dashboard_rounded, 'Dashboard'),
                  _tab(1, Icons.drive_eta_rounded, 'Conductores'),
                  _tab(2, Icons.people_rounded, 'Usuarios'),
                  _tab(3, Icons.map_rounded, 'Control Viajes'),
                  _tab(4, Icons.add_location_alt_rounded, 'Paraderos (RF55)'),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                DashboardTab(db: _db),
                ConductoresTab(
                  authService: _authService,
                  db: _db,
                  onAprobar: _aprobar,
                  onRechazar: _rechazar,
                ),
                UsuariosTab(db: _db, onToggle: _toggleUsuario),
                ViajesTab(db: _db),
                ParaderosTab(db: _db),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(int index, IconData icon, String label) {
    final active = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF1E6BFF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: active ? const Color(0xFF1E6BFF) : const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF1E6BFF) : const Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}