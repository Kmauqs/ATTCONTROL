import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

const kDefaultLocationId = '11111111-1111-1111-1111-111111111111';
const kDefaultShiftId = '22222222-2222-2222-2222-222222222222';
const kDefaultLaborId = '33333333-3333-3333-3333-333333333333';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;
  final _uuid = const Uuid();

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'attcontrol.db'),
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureSeed();
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        documento TEXT UNIQUE NOT NULL,
        nombre TEXT NOT NULL,
        apellido TEXT NOT NULL,
        cargo TEXT,
        correo TEXT,
        rh TEXT,
        eps TEXT,
        arl TEXT,
        rol TEXT NOT NULL,
        location_id TEXT,
        shift_id TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        password_hash TEXT,
        foto_path TEXT,
        carnet_path TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE locations (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        proyecto TEXT,
        cuadrilla TEXT,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        radio_metros INTEGER NOT NULL,
        tipo TEXT NOT NULL DEFAULT 'oficina',
        activo INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE shifts (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        hora_entrada TEXT NOT NULL,
        hora_salida TEXT NOT NULL,
        hora_entrada_sabado TEXT NOT NULL,
        hora_salida_sabado TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE attendance_logs (
        id TEXT PRIMARY KEY,
        client_id TEXT UNIQUE NOT NULL,
        empleado_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        marked_at TEXT NOT NULL,
        lat REAL,
        lng REAL,
        source TEXT NOT NULL,
        status TEXT NOT NULL,
        dentro_geocerca INTEGER NOT NULL,
        notas TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE incidencias (
        id TEXT PRIMARY KEY,
        empleado_id TEXT NOT NULL,
        tipo TEXT NOT NULL,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT NOT NULL,
        comentario TEXT,
        estado TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE labor_settings (
        id TEXT PRIMARY KEY,
        periodo_corte TEXT NOT NULL,
        hora_entrada TEXT NOT NULL,
        hora_salida TEXT NOT NULL,
        hora_entrada_sabado TEXT NOT NULL,
        hora_salida_sabado TEXT NOT NULL,
        extra_diurna REAL NOT NULL,
        extra_nocturna REAL NOT NULL,
        recargo_nocturno REAL NOT NULL,
        dominical_ordinario REAL NOT NULL,
        extra_diurna_festivo REAL NOT NULL,
        extra_nocturna_festivo REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE holidays (
        fecha TEXT PRIMARY KEY,
        nombre TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE locations ADD COLUMN tipo TEXT NOT NULL DEFAULT 'oficina'",
      );
      await db.execute(
        'ALTER TABLE locations ADD COLUMN activo INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute('ALTER TABLE profiles ADD COLUMN foto_path TEXT');
      await db.execute('ALTER TABLE profiles ADD COLUMN carnet_path TEXT');
    }
  }

  Future<void> _ensureSeed() async {
    final database = _db!;
    final loc = await database.query('locations');
    if (loc.isEmpty) {
      await database.insert('locations', {
        'id': kDefaultLocationId,
        'nombre': 'Obra principal',
        'proyecto': 'ATTCONTROL',
        'cuadrilla': 'Cuadrilla 1',
        'lat': 4.60971,
        'lng': -74.08175,
        'radio_metros': 250,
        'tipo': 'proyecto',
        'activo': 1,
      });
      await database.insert('shifts', {
        'id': kDefaultShiftId,
        'nombre': 'Jornada estándar CO',
        'hora_entrada': '07:00',
        'hora_salida': '17:00',
        'hora_entrada_sabado': '08:00',
        'hora_salida_sabado': '12:00',
      });
      await database.insert('labor_settings', {
        'id': kDefaultLaborId,
        'periodo_corte': 'quincenal',
        'hora_entrada': '07:00',
        'hora_salida': '17:00',
        'hora_entrada_sabado': '08:00',
        'hora_salida_sabado': '12:00',
        'extra_diurna': 0.25,
        'extra_nocturna': 0.75,
        'recargo_nocturno': 0.35,
        'dominical_ordinario': 0.90,
        'extra_diurna_festivo': 1.05,
        'extra_nocturna_festivo': 1.55,
      });
      for (final h in _holidays) {
        await database.insert('holidays', h);
      }
    }
    final people = await database.query('profiles');
    if (people.isEmpty) {
      final raw = await rootBundle.loadString('assets/seed/personal.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      for (final row in list) {
        await database.insert('profiles', {
          'id': _uuid.v5(Namespace.url.value, 'attcontrol:${row['documento']}'),
          'documento': row['documento'],
          'nombre': row['nombre'],
          'apellido': row['apellido'],
          'cargo': row['cargo'],
          'correo': row['correo'],
          'rh': row['rh'],
          'eps': row['eps'],
          'arl': row['arl'],
          'rol': row['rol'],
          'location_id': kDefaultLocationId,
          'shift_id': kDefaultShiftId,
          'activo': 1,
        });
      }
    }
  }

  static const _holidays = [
    {'fecha': '2026-01-01', 'nombre': 'Año Nuevo'},
    {'fecha': '2026-01-12', 'nombre': 'Reyes Magos'},
    {'fecha': '2026-03-23', 'nombre': 'San José'},
    {'fecha': '2026-04-02', 'nombre': 'Jueves Santo'},
    {'fecha': '2026-04-03', 'nombre': 'Viernes Santo'},
    {'fecha': '2026-05-01', 'nombre': 'Día del Trabajo'},
    {'fecha': '2026-05-18', 'nombre': 'Ascensión del Señor'},
    {'fecha': '2026-06-08', 'nombre': 'Corpus Christi'},
    {'fecha': '2026-06-15', 'nombre': 'Sagrado Corazón'},
    {'fecha': '2026-06-29', 'nombre': 'San Pedro y San Pablo'},
    {'fecha': '2026-07-20', 'nombre': 'Independencia de Colombia'},
    {'fecha': '2026-08-07', 'nombre': 'Batalla de Boyacá'},
    {'fecha': '2026-08-17', 'nombre': 'Asunción de la Virgen'},
    {'fecha': '2026-10-12', 'nombre': 'Día de la Raza'},
    {'fecha': '2026-11-02', 'nombre': 'Todos los Santos'},
    {'fecha': '2026-11-16', 'nombre': 'Independencia de Cartagena'},
    {'fecha': '2026-12-08', 'nombre': 'Inmaculada Concepción'},
    {'fecha': '2026-12-25', 'nombre': 'Navidad'},
  ];
}

