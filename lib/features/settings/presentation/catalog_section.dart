import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_repository.dart';

class CatalogSection extends StatefulWidget {
  const CatalogSection({
    super.key,
    required this.title,
    required this.hint,
    required this.table,
    required this.repo,
  });

  final String title;
  final String hint;
  final String table;
  final AppRepository repo;

  @override
  State<CatalogSection> createState() => _CatalogSectionState();
}

class _CatalogSectionState extends State<CatalogSection> {
  List<CatalogItem> _items = [];
  bool _loading = true;
  final _nombre = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await widget.repo.listCatalog(widget.table);
    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) return;
    await widget.repo.upsertCatalog(
      widget.table,
      CatalogItem(id: const Uuid().v4(), nombre: nombre),
    );
    _nombre.clear();
    await _load();
  }

  Future<void> _delete(CatalogItem item) async {
    try {
      await widget.repo.deleteCatalog(widget.table, item.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo eliminar “${item.nombre}”. Puede estar en uso.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(widget.hint, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _add,
              style: FilledButton.styleFrom(minimumSize: const Size(88, 52)),
              child: const Text('Agregar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          const Text('Aún no hay registros', style: TextStyle(color: Colors.black54)),
        for (final item in _items)
          Card(
            child: ListTile(
              leading: const Icon(Icons.label_outline, color: AppColors.forest),
              title: Text(item.nombre),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(item),
              ),
            ),
          ),
      ],
    );
  }
}
