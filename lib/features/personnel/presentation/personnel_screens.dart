import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/passwords.dart';
import '../../../data/app_repository.dart';
import '../../../data/local/local_db.dart';
import '../../auth/presentation/auth_controller.dart';
import 'profile_photo.dart';

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
            itemCount: list.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Sitios de trabajo'),
                    subtitle: const Text(
                      'Oficinas y localización del proyecto',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/sites'),
                  ),
                );
              }
              final p = list[i - 1];
              return Card(
                child: ListTile(
                  leading: ProfilePhoto(profile: p, radius: 22),
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
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  UserRol _rol = UserRol.empleado;
  bool _activo = true;
  UserProfile? _existing;
  Uint8List? _pendingFoto;
  Uint8List? _pendingCarnet;
  bool _saving = false;

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
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final profile = UserProfile(
      id: _existing?.id ?? '',
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
      fotoPath: _existing?.fotoPath,
      carnetPath: _existing?.carnetPath,
    );
    final password = _password.text;
    setState(() => _saving = true);
    try {
      final saved = await ref.read(appRepositoryProvider).upsertPersonnel(
            profile,
            password: password.isEmpty ? null : password,
          );
      if (_pendingFoto != null) {
        await ref.read(appRepositoryProvider).uploadPersonnelFile(
              profile: saved,
              kind: 'foto',
              bytes: _pendingFoto!,
              contentType: 'image/jpeg',
            );
      }
      if (_pendingCarnet != null) {
        await ref.read(appRepositoryProvider).uploadPersonnelFile(
              profile: saved,
              kind: 'carnet',
              bytes: _pendingCarnet!,
              contentType: 'application/pdf',
            );
      }
      if (mounted) {
        final me = ref.read(authControllerProvider).profile;
        if (me != null && me.id == saved.id) {
          await ref.read(authControllerProvider.notifier).refreshProfile();
        }
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<UserRol> _rolesForActor() {
    final actor = ref.read(authControllerProvider).profile;
    return UserRol.values.where((r) {
      if (r != UserRol.superAdmin) return true;
      return actor?.rol == UserRol.superAdmin || _rol == UserRol.superAdmin;
    }).toList();
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
            _mediaCard(),
            const SizedBox(height: 16),
            _field(_documento, 'ID / Documento', required: true),
            _field(_nombre, 'Nombre', required: true),
            _field(_apellido, 'Apellido', required: true),
            _field(_cargo, 'Cargo'),
            _field(_correo, 'Correo'),
            _field(_rh, 'RH'),
            _field(_eps, 'EPS'),
            _field(_arl, 'ARL'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _existing == null
                    ? 'Contraseña inicial'
                    : 'Nueva contraseña (opcional)',
              ),
              validator: (v) => validatePassword(
                v ?? '',
                required: _existing == null,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _password2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar contraseña',
              ),
              validator: (v) {
                if (_password.text.isEmpty && _existing != null) return null;
                if ((v ?? '') != _password.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<UserRol>(
              initialValue: _rol,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: _rolesForActor()
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
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _pendingFoto = bytes);
  }

  Future<void> _pickCarnet() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) return;
    if (bytes.length > 8 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El PDF no puede superar 8 MB')),
        );
      }
      return;
    }
    setState(() => _pendingCarnet = bytes);
  }

  Future<void> _openCarnet() async {
    final path = _existing?.carnetPath;
    if (path == null || path.isEmpty) return;
    final url = await ref.read(appRepositoryProvider).signedFileUrl(path);
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el carnet')),
        );
      }
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _chooseFotoSource() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Cargar imagen'),
              onTap: () {
                Navigator.pop(context);
                _pickFoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaCard() {
    final hasFoto = _pendingFoto != null || (_existing?.fotoPath ?? '').isNotEmpty;
    final hasPdf =
        _pendingCarnet != null || (_existing?.carnetPath ?? '').isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_pendingFoto != null)
              CircleAvatar(
                radius: 44,
                backgroundImage: MemoryImage(_pendingFoto!),
              )
            else if (_existing != null)
              ProfilePhoto(profile: _existing!, radius: 44)
            else
              const CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.mint,
                child: Icon(Icons.person, color: AppColors.forest, size: 40),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _chooseFotoSource,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(hasFoto ? 'Cambiar foto' : 'Agregar foto'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickCarnet,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(
                _pendingCarnet != null
                    ? 'PDF listo para guardar'
                    : hasPdf
                        ? 'Reemplazar carnet PDF'
                        : 'Cargar carnet digital (PDF)',
              ),
            ),
            if (hasPdf && _pendingCarnet == null && _existing != null)
              TextButton.icon(
                onPressed: _openCarnet,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver carnet actual'),
              ),
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
