import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/paradero_model.dart';
import 'select_pickup_controller.dart';

// ─── VISTA (MVC) ─────────────────────────────────────────────────────────────
// La vista solo renderiza estado y delega acciones al controlador.
// No contiene lógica de negocio ni acceso a datos.
//
// RF05 — Selección de Punto de Recojo
// CUS05 — Módulo 2: Reserva y Pago
class SelectPickupView extends StatefulWidget {
  const SelectPickupView({super.key});

  @override
  State<SelectPickupView> createState() => _SelectPickupViewState();
}

class _SelectPickupViewState extends State<SelectPickupView>
    with SingleTickerProviderStateMixin {
  late final SelectPickupController _ctrl;
  late final TabController _tabCtrl;

  final TextEditingController _recojoTextCtrl = TextEditingController();
  final TextEditingController _destinoTextCtrl = TextEditingController();

  // Qué campo está activo para el autocompletado
  _Campo _campoActivo = _Campo.ninguno;

  @override
  void initState() {
    super.initState();
    _ctrl = SelectPickupController();
    _tabCtrl = TabController(length: 2, vsync: this);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.cargarParaderos();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tabCtrl.dispose();
    _recojoTextCtrl.dispose();
    _destinoTextCtrl.dispose();
    super.dispose();
  }

  // ─── EA01: Alerta GPS desactivado ─────────────────────────────────────────
  void _mostrarAlertaGPS() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Color(0xFFFF9500)),
            SizedBox(width: 8),
            Text('GPS desactivado',
                style: TextStyle(color: AppColors.text, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Para capturar tu ubicación como referencia, activa el GPS en la configuración de tu dispositivo.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // ─── Confirmar selección y avanzar a RF06 ────────────────────────────────
  Future<void> _confirmar() async {
    // Captura GPS como referencia (EA01 si no está activo)
    final gpsOk = await _ctrl.capturarUbicacionGPS();
    if (!gpsOk && mounted) {
      _mostrarAlertaGPS();
      return;
    }

    if (!mounted) return;

    // Feedback visual de confirmación
    _mostrarConfirmacionVisual();

    // Navega a RF06 — Seleccionar colectivo disponible
    // ignore: use_build_context_synchronously
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AvailableCollectivosPlaceholder(
          recojo: _ctrl.recojo!,
          destino: _ctrl.destino!,
        ),
      ),
    );
  }

  void _mostrarConfirmacionVisual() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Recojo: ${_ctrl.recojo!.nombre}\nDestino: ${_ctrl.destino!.nombre}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _ctrl.cargando
          ? const _LoadingBody()
          : Column(
              children: [
                _HeaderInfo(
                  recojo: _ctrl.recojo,
                  destino: _ctrl.destino,
                ),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // Tab 1: Paraderos frecuentes
                      _ParaderosTab(
                        paraderos: _ctrl.paraderos,
                        recojoSeleccionado: _ctrl.recojo,
                        destinoSeleccionado: _ctrl.destino,
                        onSeleccionarRecojo: _ctrl.seleccionarRecojo,
                        onSeleccionarDestino: _ctrl.seleccionarDestino,
                      ),
                      // Tab 2: Buscar con autocompletado
                      _AutocompletadoTab(
                        ctrl: _ctrl,
                        recojoTextCtrl: _recojoTextCtrl,
                        destinoTextCtrl: _destinoTextCtrl,
                        campoActivo: _campoActivo,
                        onCampoChanged: (c) => setState(() => _campoActivo = c),
                      ),
                    ],
                  ),
                ),
                // Botón de confirmar (solo visible cuando selección está completa)
                _BotonConfirmar(
                  habilitado: _ctrl.seleccionCompleta,
                  onTap: _confirmar,
                ),
              ],
            ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      centerTitle: false,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Punto de recojo',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w700),
          ),
          Text(
            'RF05 — Módulo 2: Reserva y Pago',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: AppColors.textSecondary, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(Icons.location_on, size: 18),
            text: 'Paraderos frecuentes',
          ),
          Tab(
            icon: Icon(Icons.search, size: 18),
            text: 'Buscar paradero',
          ),
        ],
      ),
    );
  }
}

// ─── Enum campo activo ────────────────────────────────────────────────────────
enum _Campo { ninguno, recojo, destino }

// ─── Widget: Header con resumen de selección ─────────────────────────────────
class _HeaderInfo extends StatelessWidget {
  final ParaderoModel? recojo;
  final ParaderoModel? destino;

  const _HeaderInfo({this.recojo, this.destino});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _PuntoChip(
              icono: Icons.trip_origin,
              color: AppColors.success,
              label: 'Recojo',
              valor: recojo?.nombre ?? 'Sin seleccionar',
              seleccionado: recojo != null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward,
                color: recojo != null && destino != null
                    ? AppColors.primary
                    : AppColors.textMuted,
                size: 20),
          ),
          Expanded(
            child: _PuntoChip(
              icono: Icons.location_on,
              color: AppColors.error,
              label: 'Destino',
              valor: destino?.nombre ?? 'Sin seleccionar',
              seleccionado: destino != null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PuntoChip extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String label;
  final String valor;
  final bool seleccionado;

  const _PuntoChip({
    required this.icono,
    required this.color,
    required this.label,
    required this.valor,
    required this.seleccionado,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: seleccionado
            ? Border.all(color: color.withOpacity(0.6), width: 1.2)
            : Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10)),
                Text(
                  valor,
                  style: TextStyle(
                    color: seleccionado
                        ? AppColors.text
                        : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: seleccionado
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widget: Tab paraderos frecuentes ────────────────────────────────────────
class _ParaderosTab extends StatelessWidget {
  final List<ParaderoModel> paraderos;
  final ParaderoModel? recojoSeleccionado;
  final ParaderoModel? destinoSeleccionado;
  final ValueChanged<ParaderoModel> onSeleccionarRecojo;
  final ValueChanged<ParaderoModel> onSeleccionarDestino;

  const _ParaderosTab({
    required this.paraderos,
    required this.recojoSeleccionado,
    required this.destinoSeleccionado,
    required this.onSeleccionarRecojo,
    required this.onSeleccionarDestino,
  });

  @override
  Widget build(BuildContext context) {
    if (paraderos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: AppColors.textMuted, size: 48),
            SizedBox(height: 12),
            Text('Sin conexión — mostrando paraderos base',
                style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _SectionLabel(
            icono: Icons.route,
            texto: 'Ruta Chosica → Lima',
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: paraderos.length,
            itemBuilder: (_, i) {
              final p = paraderos[i];
              final esRecojo = recojoSeleccionado?.id == p.id;
              final esDestino = destinoSeleccionado?.id == p.id;

              return _ParaderoCard(
                paradero: p,
                esRecojo: esRecojo,
                esDestino: esDestino,
                onTapRecojo: () => onSeleccionarRecojo(p),
                onTapDestino: () => onSeleccionarDestino(p),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ParaderoCard extends StatelessWidget {
  final ParaderoModel paradero;
  final bool esRecojo;
  final bool esDestino;
  final VoidCallback onTapRecojo;
  final VoidCallback onTapDestino;

  const _ParaderoCard({
    required this.paradero,
    required this.esRecojo,
    required this.esDestino,
    required this.onTapRecojo,
    required this.onTapDestino,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esRecojo
              ? AppColors.success.withOpacity(0.5)
              : esDestino
                  ? AppColors.error.withOpacity(0.5)
                  : AppColors.border,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${paradero.orden}',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
        ),
        title: Text(
          paradero.nombre,
          style: const TextStyle(
              color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          paradero.referencia,
          style:
              const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón Recojo
            _ActionChip(
              label: 'Recojo',
              seleccionado: esRecojo,
              color: AppColors.success,
              onTap: onTapRecojo,
            ),
            const SizedBox(width: 6),
            // Botón Destino
            _ActionChip(
              label: 'Destino',
              seleccionado: esDestino,
              color: AppColors.error,
              onTap: onTapDestino,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.seleccionado,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: seleccionado ? color : Colors.transparent,
          border: Border.all(
              color: seleccionado ? color : AppColors.border, width: 1.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: seleccionado ? Colors.white : AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Widget: Tab autocompletado ───────────────────────────────────────────────
class _AutocompletadoTab extends StatelessWidget {
  final SelectPickupController ctrl;
  final TextEditingController recojoTextCtrl;
  final TextEditingController destinoTextCtrl;
  final _Campo campoActivo;
  final ValueChanged<_Campo> onCampoChanged;

  const _AutocompletadoTab({
    required this.ctrl,
    required this.recojoTextCtrl,
    required this.destinoTextCtrl,
    required this.campoActivo,
    required this.onCampoChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo recojo
          _AutocompletadoField(
            ctrl: ctrl,
            textCtrl: recojoTextCtrl,
            label: 'Punto de recojo',
            icono: Icons.trip_origin,
            color: AppColors.success,
            activo: campoActivo == _Campo.recojo,
            valorSeleccionado: ctrl.recojo?.nombre,
            onFocus: () {
              onCampoChanged(_Campo.recojo);
              ctrl.filtrarSugerencias(recojoTextCtrl.text);
            },
            onChanged: (v) => ctrl.filtrarSugerencias(v),
            onSeleccionar: (p) {
              recojoTextCtrl.text = p.nombre;
              ctrl.seleccionarRecojo(p);
              ctrl.limpiarSugerencias();
              onCampoChanged(_Campo.ninguno);
            },
          ),
          const SizedBox(height: 14),
          // Campo destino
          _AutocompletadoField(
            ctrl: ctrl,
            textCtrl: destinoTextCtrl,
            label: 'Punto de destino',
            icono: Icons.location_on,
            color: AppColors.error,
            activo: campoActivo == _Campo.destino,
            valorSeleccionado: ctrl.destino?.nombre,
            onFocus: () {
              onCampoChanged(_Campo.destino);
              ctrl.filtrarSugerencias(destinoTextCtrl.text);
            },
            onChanged: (v) => ctrl.filtrarSugerencias(v),
            onSeleccionar: (p) {
              destinoTextCtrl.text = p.nombre;
              ctrl.seleccionarDestino(p);
              ctrl.limpiarSugerencias();
              onCampoChanged(_Campo.ninguno);
            },
          ),

          // Sugerencias
          if (ctrl.sugerencias.isNotEmpty && campoActivo != _Campo.ninguno) ...[
            const SizedBox(height: 12),
            const _SectionLabel(
                icono: Icons.auto_fix_high, texto: 'Sugerencias'),
            const SizedBox(height: 6),
            Expanded(
              child: _SugerenciasList(
                sugerencias: ctrl.sugerencias,
                campoActivo: campoActivo,
                onSeleccionar: (p) {
                  if (campoActivo == _Campo.recojo) {
                    recojoTextCtrl.text = p.nombre;
                    ctrl.seleccionarRecojo(p);
                  } else {
                    destinoTextCtrl.text = p.nombre;
                    ctrl.seleccionarDestino(p);
                  }
                  ctrl.limpiarSugerencias();
                  onCampoChanged(_Campo.ninguno);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AutocompletadoField extends StatelessWidget {
  final SelectPickupController ctrl;
  final TextEditingController textCtrl;
  final String label;
  final IconData icono;
  final Color color;
  final bool activo;
  final String? valorSeleccionado;
  final VoidCallback onFocus;
  final ValueChanged<String> onChanged;
  final ValueChanged<ParaderoModel> onSeleccionar;

  const _AutocompletadoField({
    required this.ctrl,
    required this.textCtrl,
    required this.label,
    required this.icono,
    required this.color,
    required this.activo,
    required this.valorSeleccionado,
    required this.onFocus,
    required this.onChanged,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: activo ? color : AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: textCtrl,
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          onTap: onFocus,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            hintText: 'Escribe o selecciona un paradero...',
            hintStyle:
                const TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: Icon(icono, color: color, size: 18),
            suffixIcon: valorSeleccionado != null
                ? Icon(Icons.check_circle, color: color, size: 18)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withOpacity(0.6), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SugerenciasList extends StatelessWidget {
  final List<ParaderoModel> sugerencias;
  final _Campo campoActivo;
  final ValueChanged<ParaderoModel> onSeleccionar;

  const _SugerenciasList({
    required this.sugerencias,
    required this.campoActivo,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final color = campoActivo == _Campo.recojo ? AppColors.success : AppColors.error;

    return ListView.separated(
      itemCount: sugerencias.length,
      separatorBuilder: (_, __) =>
          const Divider(color: AppColors.border, height: 1),
      itemBuilder: (_, i) {
        final p = sugerencias[i];
        return ListTile(
          dense: true,
          onTap: () => onSeleccionar(p),
          leading: Icon(Icons.location_on, color: color, size: 18),
          title: Text(p.nombre,
              style: const TextStyle(color: AppColors.text, fontSize: 13)),
          subtitle: Text(p.referencia,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          tileColor: AppColors.surfaceVariant,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      },
    );
  }
}

// ─── Widget: Botón confirmar ──────────────────────────────────────────────────
class _BotonConfirmar extends StatelessWidget {
  final bool habilitado;
  final VoidCallback onTap;

  const _BotonConfirmar({required this.habilitado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      color: AppColors.surface,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: habilitado ? onTap : null,
          icon: const Icon(Icons.directions_bus_rounded, size: 20),
          label: const Text(
            'Ver colectivos disponibles',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                habilitado ? AppColors.primary : AppColors.border,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.surfaceVariant,
            disabledForegroundColor: AppColors.textMuted,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: habilitado ? 3 : 0,
          ),
        ),
      ),
    );
  }
}

// ─── Widget: Loading state ────────────────────────────────────────────────────
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text('Cargando paraderos...',
              style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ─── Widget: Sección label ────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _SectionLabel({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, color: AppColors.primary, size: 16),
        const SizedBox(width: 6),
        Text(texto,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ],
    );
  }
}

// ─── Placeholder RF06 ─────────────────────────────────────────────────────────
// En producción esto sería SelectColectivoView(recojo, destino)
class _AvailableCollectivosPlaceholder extends StatelessWidget {
  final ParaderoModel recojo;
  final ParaderoModel destino;

  const _AvailableCollectivosPlaceholder({
    required this.recojo,
    required this.destino,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Colectivos disponibles',
            style: TextStyle(color: AppColors.text)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_bus_rounded,
                  color: AppColors.primary, size: 64),
              const SizedBox(height: 16),
              const Text('RF06 — Seleccionar Colectivo',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              _InfoRow(label: 'Recojo', valor: recojo.nombre,
                  color: AppColors.success),
              const SizedBox(height: 8),
              _InfoRow(label: 'Destino', valor: destino.nombre,
                  color: AppColors.error),
              const SizedBox(height: 24),
              const Text(
                'Aquí se mostrarán los colectivos disponibles para esta ruta.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;

  const _InfoRow({required this.label, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: color, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              Text(valor,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
