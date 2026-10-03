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
      version: 4,
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
        await _createBusinessTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createBusinessTables(db);
        if (oldVersion < 3) await _upgradeBusinessTablesV3(db);
        if (oldVersion < 4) await _upgradeBusinessTablesV4(db);
      },
    );
  }

  static Future<void> _createBusinessTables(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS projects(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER NOT NULL,name TEXT NOT NULL,address TEXT,category TEXT,aluminum_brand TEXT,aluminum_type TEXT,aluminum_system TEXT,accessory TEXT,dimensions TEXT,quantity REAL DEFAULT 0,status TEXT,start_date TEXT,production_date TEXT,install_date TEXT,photo_paths TEXT,note TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS quotes(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER NOT NULL,project_id INTEGER,code TEXT NOT NULL,amount REAL DEFAULT 0,status TEXT,valid_until TEXT,file_path TEXT,note TEXT,created_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS contracts(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER NOT NULL,project_id INTEGER,code TEXT NOT NULL,value REAL DEFAULT 0,signed_at TEXT,install_date TEXT,warranty_months INTEGER DEFAULT 12,status TEXT,file_path TEXT,note TEXT,created_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS payments(id INTEGER PRIMARY KEY AUTOINCREMENT,contract_id INTEGER NOT NULL,customer_id INTEGER NOT NULL,amount REAL DEFAULT 0,paid_at TEXT NOT NULL,method TEXT,note TEXT)');
  }

  static Future<void> _upgradeBusinessTablesV3(Database db) async {
    Future<void> addColumn(String table, String definition) async {
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN $definition');
      } catch (_) {
        // Column already exists or the table was freshly created.
      }
    }

    await addColumn('projects', 'aluminum_type TEXT');
    await addColumn('projects', 'dimensions TEXT');
    await addColumn('projects', 'quantity REAL DEFAULT 0');
    await addColumn('projects', 'production_date TEXT');
    await addColumn('projects', 'photo_paths TEXT');
    await addColumn('quotes', 'file_path TEXT');
    await addColumn('contracts', 'file_path TEXT');
  }

  static Future<void> _upgradeBusinessTablesV4(Database db) async {
    try {
      await db.execute('ALTER TABLE projects ADD COLUMN aluminum_brand TEXT');
    } catch (_) {
      // Column already exists.
    }
    try {
      await db.execute("UPDATE projects SET aluminum_brand = aluminum_type WHERE (aluminum_brand IS NULL OR aluminum_brand = '') AND aluminum_type IS NOT NULL AND aluminum_type != ''");
    } catch (_) {
      // Keep migration tolerant for fresh installs.
    }
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

  Future<int> addTask({int? customerId, required String title, required String dueDate, required String priority, required String note}) async {
    final database = await db;
    return database.insert('tasks', {
      'customer_id': customerId,
      'title': title,
      'due_date': dueDate,
      'priority': priority,
      'completed': 0,
      'note': note,
    });
  }

  Future<List<Map<String, Object?>>> getTasks({bool onlyOpen = false}) async {
    final database = await db;
    final rows = await database.query(
      'tasks',
      where: onlyOpen ? 'completed = 0' : null,
      orderBy: 'completed ASC, due_date ASC',
    );
    return rows;
  }

  Future<int> setTaskCompleted(int id, bool completed) async {
    final database = await db;
    return database.update('tasks', {'completed': completed ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addAppointment({
    int? customerId,
    required String title,
    required String startsAt,
    required int durationMinutes,
    required String location,
    required String note,
  }) async {
    final database = await db;
    return database.insert('appointments', {
      'customer_id': customerId,
      'title': title,
      'starts_at': startsAt,
      'duration_minutes': durationMinutes,
      'location': location,
      'note': note,
      'completed': 0,
    });
  }

  Future<List<Map<String, Object?>>> getAppointmentsForDay(DateTime date) async {
    final database = await db;
    final prefix = date.toIso8601String().substring(0, 10);
    return database.query(
      'appointments',
      where: 'starts_at LIKE ?',
      whereArgs: [prefix + '%'],
      orderBy: 'starts_at ASC',
    );
  }

  Future<int> addProject(Map<String, Object?> data) async {
    final database = await db;
    return database.insert('projects', data);
  }

  Future<List<Map<String, Object?>>> getProjects({int? customerId}) async {
    final database = await db;
    return database.query('projects', where: customerId == null ? null : 'customer_id = ?', whereArgs: customerId == null ? null : [customerId], orderBy: 'updated_at DESC');
  }

  Future<int> addQuote(Map<String, Object?> data) async {
    final database = await db;
    return database.insert('quotes', data);
  }

  Future<List<Map<String, Object?>>> getQuotes({int? customerId}) async {
    final database = await db;
    return database.query('quotes', where: customerId == null ? null : 'customer_id = ?', whereArgs: customerId == null ? null : [customerId], orderBy: 'created_at DESC');
  }

  Future<int> addContract(Map<String, Object?> data) async {
    final database = await db;
    return database.insert('contracts', data);
  }

  Future<List<Map<String, Object?>>> getContracts({int? customerId}) async {
    final database = await db;
    return database.query('contracts', where: customerId == null ? null : 'customer_id = ?', whereArgs: customerId == null ? null : [customerId], orderBy: 'created_at DESC');
  }

  Future<int> addPayment(Map<String, Object?> data) async {
    final database = await db;
    return database.insert('payments', data);
  }

  Future<List<Map<String, Object?>>> getPayments({int? customerId, int? contractId}) async {
    final database = await db;
    String? where;
    List<Object?>? args;
    if (contractId != null) {
      where = 'contract_id = ?';
      args = [contractId];
    } else if (customerId != null) {
      where = 'customer_id = ?';
      args = [customerId];
    }
    return database.query('payments', where: where, whereArgs: args, orderBy: 'paid_at DESC');
  }

  Future<Map<String, double>> getFinanceStats() async {
    final database = await db;
    final contractRows = await database.rawQuery('SELECT COALESCE(SUM(value),0) AS total FROM contracts');
    final paymentRows = await database.rawQuery('SELECT COALESCE(SUM(amount),0) AS total FROM payments');
    final contractValue = ((contractRows.first['total'] ?? 0) as num).toDouble();
    final paid = ((paymentRows.first['total'] ?? 0) as num).toDouble();
    return {'contractValue': contractValue, 'paid': paid, 'receivable': contractValue - paid};
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