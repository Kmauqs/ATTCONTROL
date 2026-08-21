import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_repository.dart';
import '../../../data/local/local_db.dart';

class PersonnelListScreen extends ConsumerWidget {
  const PersonnelListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/personnel/new'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Agregar'),
      ),
      body: FutureBuilder(
        future: ref.read(appRepositoryProvider).listPersonnel(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final p = list[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.mint,
                    child: Text(p.initials),
                  ),
                  title: Text(p.fullName),
                  subtitle: Text('${p.documento} · ${p.rol.label}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/personnel/${p.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PersonnelFormScreen extends ConsumerStatefulWidget {
  const PersonnelFormScreen({super.key, this.id});
  final String? id;

  @override
  ConsumerState<PersonnelFormScreen> createState() =>
      _PersonnelFormScreenState();
}

class _PersonnelFormScreenState extends ConsumerState<PersonnelFormScreen> {
  final _form = GlobalKey<FormState>();
  final _documento = TextEditingController();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _cargo = TextEditingController();
  final _correo = TextEditingController();
  final _rh = TextEditingController();
  final _eps = TextEditingController();
  final _arl = TextEditingController();
  UserRol _rol = UserRol.empleado;
  bool _activo = true;
  UserProfile? _existing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.id == null) return;
    final list = await ref.read(appRepositoryProvider).listPersonnel();
    final p = list.where((e) => e.id == widget.id).firstOrNull;
    if (p == null) return;
    _existing = p;
    _documento.text = p.documento;
    _nombre.text = p.nombre;
    _apellido.text = p.apellido;
    _cargo.text = p.cargo ?? '';
    _correo.text = p.correo ?? '';
    _rh.text = p.rh ?? '';
    _eps.text = p.eps ?? '';
    _arl.text = p.arl ?? '';
    _rol = p.rol;
    _activo = p.activo;
    setState(() {});
  }

  @override
  void dispose() {
    _documento.dispose();
    _nombre.dispose();
    _apellido.dispose();
    _cargo.dispose();
    _correo.dispose();
    _rh.dispose();
    _eps.dispose();
    _arl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final profile = UserProfile(
      id: _existing?.id ?? const Uuid().v4(),
      documento: _documento.text.trim(),
      nombre: _nombre.text.trim(),
      apellido: _apellido.text.trim(),
      cargo: _cargo.text.trim(),
      correo: _correo.text.trim(),
      rh: _rh.text.trim(),
      eps: _eps.text.trim(),
      arl: _arl.text.trim(),
      rol: _rol,
      locationId: _existing?.locationId ?? kDefaultLocationId,
      shiftId: _existing?.shiftId ?? kDefaultShiftId,
      activo: _activo,
    );
    await ref.read(appRepositoryProvider).upsertPersonnel(profile);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (_existing == null) return;
    await ref.read(appRepositoryProvider).deletePersonnel(_existing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Nuevo personal' : 'Editar personal'),
        actions: [
          if (_existing != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_documento, 'ID / Documento', required: true),
            _field(_nombre, 'Nombre', required: true),
            _field(_apellido, 'Apellido', required: true),
            _field(_cargo, 'Cargo'),
            _field(_correo, 'Correo'),
            _field(_rh, 'RH'),
            _field(_eps, 'EPS'),
            _field(_arl, 'ARL'),
            const SizedBox(height: 8),
            DropdownButtonFormField<UserRol>(
              initialValue: _rol,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: UserRol.values
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                  .toList(),
              onChanged: (v) => setState(() => _rol = v ?? _rol),
            ),
            SwitchListTile(
              title: const Text('Activo'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
            : null,
      ),
    );
  }
}
