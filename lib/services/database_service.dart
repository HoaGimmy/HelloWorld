import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
 DatabaseService._(); static final instance=DatabaseService._(); Database? _db;
 Future<Database> get db async=>_db??=await _open();
 Future<Database> _open() async { final d=await getApplicationDocumentsDirectory(); return openDatabase('${d.path}/mpwindows_crm.db',version:1,onCreate:(db,_) async { await db.execute('CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT,zalo TEXT,address TEXT,source TEXT,stage TEXT,need TEXT,budget REAL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)'); await db.execute('CREATE TABLE activities(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER NOT NULL,type TEXT,title TEXT NOT NULL,content TEXT,created_at TEXT NOT NULL)'); await db.execute('CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER,title TEXT NOT NULL,due_date TEXT NOT NULL,priority TEXT,completed INTEGER DEFAULT 0,note TEXT)'); await db.execute('CREATE TABLE appointments(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER,title TEXT NOT NULL,starts_at TEXT NOT NULL,duration_minutes INTEGER DEFAULT 60,location TEXT,note TEXT,completed INTEGER DEFAULT 0)'); }); }
}
