import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
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
    final list =
        await ref.read(appRepositoryProvider).listSites(onlyActive: false);
    if (mounted) {
      setState(() {
        _sites = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Localizaciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/sites/new');
          await _load();
        },
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Nueva localización'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                'Oficinas y proyectos. El GPS de cada punto se usa para validar '
                'la entrada y la salida del personal.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            if (_sites.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('Aún no hay localizaciones'),
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
                    [
                      site.tipoLabel,
                      if ((site.direccion ?? '').isNotEmpty) site.direccion,
                      '${site.radioMetros} m',
                      if (!site.activo) 'inactivo',
                    ].join(' · '),
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
                  onTap: () async {
                    await context.push('/sites/${site.id}');
                    await _load();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SiteFormScreen extends ConsumerStatefulWidget {
  const SiteFormScreen({super.key, this.id});
  final String? id;

  @override
  ConsumerState<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends ConsumerState<SiteFormScreen> {
  final _nombre = TextEditingController();
  final _direccion = TextEditingController();
  final _cliente = TextEditingController();
  final _contrato = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _radio = TextEditingController(text: '250');
  String _tipo = 'oficina';
  String? _cuadrilla;
  bool _activo = true;
  bool _gpsBusy = false;
  bool _saving = false;
  bool _ready = false;
  WorkSite? _existing;
  List<CatalogItem> _cuadrillas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final actor = ref.read(authControllerProvider).profile;
    if (actor == null || !actor.rol.isStaff) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    final repo = ref.read(appRepositoryProvider);
    final crews = await repo.listCatalog('cuadrillas');
    WorkSite? existing;
    if (widget.id != null) {
      final sites = await repo.listSites(onlyActive: false);
      existing = sites.where((s) => s.id == widget.id).firstOrNull;
    }
    if (!mounted) return;
    setState(() {
      _cuadrillas = crews;
      _existing = existing;
      _ready = true;
      if (existing != null) {
        _nombre.text = existing.nombre;
        _direccion.text = existing.direccion ?? '';
        _cliente.text = existing.cliente ?? '';
        _contrato.text = existing.contrato ?? '';
        _lat.text = existing.lat.toString();
        _lng.text = existing.lng.toString();
        _radio.text = '${existing.radioMetros}';
        _tipo = existing.tipo;
        _cuadrilla = existing.cuadrilla;
        _activo = existing.activo;
      }
    });
  }

  @override
  void dispose() {
    _nombre.dispose();
    _direccion.dispose();
    _cliente.dispose();
    _contrato.dispose();
    _lat.dispose();
    _lng.dispose();
    _radio.dispose();
    super.dispose();
  }

  LatLng? get _point {
    final lat = double.tryParse(_lat.text.replaceAll(',', '.'));
    final lng = double.tryParse(_lng.text.replaceAll(',', '.'));
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
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
      setState(() {
        _lat.text = pos.latitude.toStringAsFixed(6);
        _lng.text = pos.longitude.toStringAsFixed(6);
      });
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

  Future<void> _save() async {
    final nombre = _nombre.text.trim();
    final lat = double.tryParse(_lat.text.replaceAll(',', '.'));
    final lng = double.tryParse(_lng.text.replaceAll(',', '.'));
    final radio = int.tryParse(_radio.text.trim());
    if (nombre.isEmpty || lat == null || lng == null || radio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa nombre, coordenadas GPS y radio'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(appRepositoryProvider).upsertSite(
            WorkSite(
              id: _existing?.id ?? const Uuid().v4(),
              nombre: nombre,
              proyecto: _tipo == 'proyecto' ? nombre : _existing?.proyecto,
              cuadrilla: _cuadrilla,
              lat: lat,
              lng: lng,
              radioMetros: radio,
              tipo: _tipo,
              activo: _activo,
              direccion: _direccion.text.trim(),
              cliente: _cliente.text.trim(),
              contrato: _contrato.text.trim(),
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final point = _point;
    final crewNames = {for (final c in _cuadrillas) c.nombre};
    final selectedCrew = crewNames.contains(_cuadrilla) ? _cuadrilla : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Nueva localización' : 'Editar localización'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            controller: _direccion,
            decoration: const InputDecoration(labelText: 'Dirección'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cliente,
            decoration: const InputDecoration(
              labelText: 'Cliente (opcional)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contrato,
            decoration: const InputDecoration(
              labelText: 'No. de contrato (opcional)',
            ),
          ),
          const SizedBox(height: 10),
          if (_cuadrillas.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: selectedCrew,
              decoration: const InputDecoration(labelText: 'Cuadrilla'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin asignar')),
                ..._cuadrillas.map(
                  (c) => DropdownMenuItem(value: c.nombre, child: Text(c.nombre)),
                ),
              ],
              onChanged: (v) => setState(() => _cuadrilla = v),
            ),
          const SizedBox(height: 16),
          const Text(
            'Localización GPS',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const Text(
            'Estas coordenadas validan el ingreso y la salida del personal.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                key: ValueKey('${_lat.text},${_lng.text}'),
                options: MapOptions(
                  initialCenter: point ?? const LatLng(4.60971, -74.08175),
                  initialZoom: point == null ? 11 : 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.attcontrol.attcontrol',
                  ),
                  if (point != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 36,
                          height: 36,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.forest,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _lat,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(labelText: 'Latitud'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _lng,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(labelText: 'Longitud'),
            onChanged: (_) => setState(() {}),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activa'),
            value: _activo,
            onChanged: (v) => setState(() => _activo = v),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
