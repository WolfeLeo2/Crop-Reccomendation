import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class HistoryService {
  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'farmwise.db');

    _db = await openDatabase(
      path,
      version: 2, // Bump version for migration
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE history(id INTEGER PRIMARY KEY AUTOINCREMENT, crop TEXT, date TEXT, details TEXT, planting_advice TEXT)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add planting_advice column for existing users
          await db.execute(
            'ALTER TABLE history ADD COLUMN planting_advice TEXT',
          );
        }
      },
    );
  }

  Future<void> saveRecommendation(
    String crop,
    String details, {
    String? plantingAdvice,
  }) async {
    if (_db == null) await init();
    await _db!.insert('history', {
      'crop': crop,
      'date': DateTime.now().toIso8601String(),
      'details': details,
      'planting_advice': plantingAdvice,
    });
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    if (_db == null) await init();
    final List<Map<String, dynamic>> maps = await _db!.query(
      'history',
      orderBy: 'id DESC',
    );
    return maps;
  }
}
