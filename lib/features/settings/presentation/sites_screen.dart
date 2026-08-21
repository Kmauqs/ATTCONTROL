import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_repository.dart';
import '../../auth/presentation/auth_controller.dart';

class SitesScreen extends ConsumerStatefulWidget {
  const SitesScreen({super.key});

  @override
  ConsumerState<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends ConsumerState<SitesScreen> {
  List<WorkSite> _sites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ref.read(appRepositoryProvider).listSites(onlyActive: false);
    if (mounted) {
      setState(() {
        _sites = list;
        _loading = false;
      });
    }
  }

  Future<void> _edit([WorkSite? existing]) async {
    final actor = ref.read(authControllerProvider).profile;
    if (actor == null || !actor.rol.isStaff) return;
    final saved = await showModalBottomSheet<WorkSite>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SiteFormSheet(existing: existing),
    );
    if (saved == null) return;
    await ref.read(appRepositoryProvider).upsertSite(saved);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Sitios de trabajo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Agregar sitio'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                'Puedes registrar oficinas y la localización del proyecto. '
                'El personal ficha si está dentro de cualquiera de estos puntos.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            if (_sites.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('Aún no hay sitios'),
                  subtitle: Text('Agrega una oficina o un proyecto'),
                ),
              ),
            for (final site in _sites)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.mint,
                    child: Icon(
                      site.tipo == 'proyecto'
                          ? Icons.construction_outlined
                          : Icons.apartment_outlined,
                      color: AppColors.forest,
                    ),
                  ),
                  title: Text(site.nombre),
                  subtitle: Text(
                    '${site.tipoLabel} · ${site.radioMetros} m'
                    '${site.activo ? '' : ' · inactivo'}',
                  ),
                  trailing: Switch(
                    value: site.activo,
                    onChanged: (v) async {
                      await ref
                          .read(appRepositoryProvider)
                          .setSiteActive(site.id, v);
                      await _load();
                    },
                  ),
                  onTap: () => _edit(site),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SiteFormSheet extends StatefulWidget {
  const _SiteFormSheet({this.existing});
  final WorkSite? existing;

  @override
  State<_SiteFormSheet> createState() => _SiteFormSheetState();
}

class _SiteFormSheetState extends State<_SiteFormSheet> {
  final _nombre = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _radio = TextEditingController(text: '250');
  String _tipo = 'oficina';
  bool _gpsBusy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nombre.text = e.nombre;
      _lat.text = e.lat.toString();
      _lng.text = e.lng.toString();
      _radio.text = '${e.radioMetros}';
      _tipo = e.tipo;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _lat.dispose();
    _lng.dispose();
    _radio.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _gpsBusy = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Se necesita la ubicación para marcar el punto');
      }
      final pos = await Geolocator.getCurrentPosition();
      _lat.text = pos.latitude.toStringAsFixed(6);
      _lng.text = pos.longitude.toStringAsFixed(6);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  void _save() {
    final nombre = _nombre.text.trim();
    final lat = double.tryParse(_lat.text.replaceAll(',', '.'));
    final lng = double.tryParse(_lng.text.replaceAll(',', '.'));
    final radio = int.tryParse(_radio.text.trim());
    if (nombre.isEmpty || lat == null || lng == null || radio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre, coordenadas y radio')),
      );
      return;
    }
    Navigator.pop(
      context,
      WorkSite(
        id: widget.existing?.id ?? const Uuid().v4(),
        nombre: nombre,
        proyecto: widget.existing?.proyecto,
        cuadrilla: widget.existing?.cuadrilla,
        lat: lat,
        lng: lng,
        radioMetros: radio,
        tipo: _tipo,
        activo: widget.existing?.activo ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + pad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Nuevo sitio' : 'Editar sitio',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'oficina', child: Text('Oficina')),
                DropdownMenuItem(value: 'proyecto', child: Text('Proyecto')),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _lat,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Latitud'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _lng,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Longitud'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _radio,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radio autorizado (metros)',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _gpsBusy ? null : _useGps,
              icon: _gpsBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('Usar mi ubicación actual'),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _save, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}
