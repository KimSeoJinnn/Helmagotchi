import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  DBHelper._internal();
  factory DBHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'helmagotchi.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 유저 정보 테이블 (레벨, 경험치 저장)
        await db.execute('''
          CREATE TABLE user(
            uid TEXT PRIMARY KEY,
            level INTEGER,
            currentExp INTEGER
          )
        ''');
        // 운동 기록 테이블 (통계용)
        await db.execute('''
          CREATE TABLE workout_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT,
            count INTEGER,
            timestamp TEXT
          )
        ''');
      },
    );
  }
}
