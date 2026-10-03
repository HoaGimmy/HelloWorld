import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/activity.dart';
import '../models/customer.dart';

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();

  Database? _db;
  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = dir.path + '/mpwindows_crm.db';
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT,zalo TEXT,address TEXT,source TEXT,stage TEXT,need TEXT,budget REAL DEFAULT 0,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE activities(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER NOT NULL,type TEXT,title TEXT NOT NULL,content TEXT,created_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER,title TEXT NOT NULL,due_date TEXT NOT NULL,priority TEXT,completed INTEGER DEFAULT 0,note TEXT)',
        );
        await db.execute(
          'CREATE TABLE appointments(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER,title TEXT NOT NULL,starts_at TEXT NOT NULL,duration_minutes INTEGER DEFAULT 60,location TEXT,note TEXT,completed INTEGER DEFAULT 0)',
        );
      },
    );
  }

  Future<List<Customer>> getCustomers({String query = ''}) async {
    final database = await db;
    final q = query.trim();
    final rows = await database.query(
      'customers',
      where: q.isEmpty ? null : 'name LIKE ? OR phone LIKE ? OR address LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%', '%$q%'],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> getCustomer(int id) async {
    final database = await db;
    final rows = await database.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Customer.fromMap(rows.first);
  }

  Future<int> insertCustomer(Customer customer) async {
    final database = await db;
    final map = Map<String, Object?>.from(customer.toMap())..remove('id');
    return database.insert('customers', map);
  }

  Future<int> updateCustomer(Customer customer) async {
    if (customer.id == null) throw ArgumentError('Customer id is required.');
    final database = await db;
    final map = Map<String, Object?>.from(customer.toMap())..remove('id');
    return database.update('customers', map, where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<int> deleteCustomer(int id) async {
    final database = await db;
    await database.delete('activities', where: 'customer_id = ?', whereArgs: [id]);
    return database.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addActivity(Activity activity) async {
    final database = await db;
    return database.insert('activities', {
      'customer_id': activity.customerId,
      'type': activity.type,
      'title': activity.title,
      'content': activity.content,
      'created_at': activity.createdAt,
    });
  }

  Future<List<Activity>> getActivities(int customerId) async {
    final database = await db;
    final rows = await database.query(
      'activities',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Activity.fromMap).toList();
  }

  Future<int> updateCustomerStage(int customerId, String stage) async {
    final database = await db;
    return database.update(
      'customers',
      {
        'stage': stage,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  Future<Map<String, int>> getCustomerStats() async {
    final database = await db;
    Future<int> count(String sql) async => Sqflite.firstIntValue(await database.rawQuery(sql)) ?? 0;
    return {
      'total': await count('SELECT COUNT(*) FROM customers'),
      'contracts': await count("SELECT COUNT(*) FROM customers WHERE stage = 'Chốt hợp đồng'"),
      'surveys': await count("SELECT COUNT(*) FROM customers WHERE stage = 'Khảo sát'"),
      'quotes': await count("SELECT COUNT(*) FROM customers WHERE stage = 'Báo giá'"),
    };
  }
}