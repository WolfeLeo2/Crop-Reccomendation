import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class HistoryService {
  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'farmwise.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE history(id INTEGER PRIMARY KEY AUTOINCREMENT, crop TEXT, date TEXT, details TEXT)',
        );
      },
    );
  }

  Future<void> saveRecommendation(String crop, String details) async {
    if (_db == null) await init();
    await _db!.insert('history', {
      'crop': crop,
      'date': DateTime.now().toIso8601String(),
      'details': details,
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
