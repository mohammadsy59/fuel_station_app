import 'dart:convert';
import 'dart:io';

import 'package:fuel_station_app/models/cashbox.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fuel_station.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    print('Database path: $path'); // Log the database path for debugging
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // Create tanks table
    await db.execute('''
      CREATE TABLE tanks (
        id TEXT PRIMARY KEY,
        fuelType TEXT,
        capacity REAL,
        currentLevel REAL
      )
    ''');

    // Create pumps table
    await db.execute('''
      CREATE TABLE pumps (
        id TEXT PRIMARY KEY,
        connectedTankId TEXT,
        digitalCounter REAL,
        mechanicalCounter REAL
      )
    ''');

    // Create cashbox table
    await db.execute('''
      CREATE TABLE cashbox (
        id INTEGER PRIMARY KEY,
        usd REAL,
        syp REAL,
        tryCurrency REAL
      )
    ''');
    await db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      currency TEXT,
      amount REAL,
      type TEXT,
      date TEXT,
      note TEXT -- Add a note column
    )
  ''');
    // Create invoices table
    await db.execute('''
    CREATE TABLE invoices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customerName TEXT,
      fuelType TEXT,
      quantity REAL,
      pricePerUnit REAL,
      totalAmount REAL,
      currency TEXT,
      date TEXT,
      paymentStatus TEXT
    )
  ''');

    // Create debts table
    await db.execute('''
    CREATE TABLE debts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customerName TEXT,
      totalDebt REAL,
      currency TEXT,
      date TEXT,
      status TEXT
    )
  ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS settings (
      id INTEGER PRIMARY KEY,
      password TEXT NOT NULL
    )
  ''');

    // Insert initial data
    await _insertInitialData(db);
  }

  Future<void> _insertInitialData(Database db) async {
    final passwordMaps = await db.query('settings');
    if (passwordMaps.isEmpty) {
      await db.insert('settings', {'id': 1, 'password': '1234'});
    }
    // Insert tanks
    await db.insert('tanks', {
      'id': 'T1',
      'fuelType': 'Diesel',
      'capacity': 5000,
      'currentLevel': 3000,
    });
    await db.insert('tanks', {
      'id': 'T2',
      'fuelType': 'Gasoline',
      'capacity': 4000,
      'currentLevel': 2500,
    });

    // Insert pumps
    await db.insert('pumps', {
      'id': 'P1',
      'connectedTankId': 'T1',
      'digitalCounter': 1000,
      'mechanicalCounter': 1000,
    });
    await db.insert('pumps', {
      'id': 'P2',
      'connectedTankId': 'T2',
      'digitalCounter': 800,
      'mechanicalCounter': 800,
    });

    // Insert cashbox
    await db.insert('cashbox', {
      'id': 1,
      'usd': 1000,
      'syp': 5000000,
      'tryCurrency': 20000,
    });

    // Insert initial transactions
    await db.insert('transactions', {
      'currency': 'USD',
      'amount': 500,
      'type': 'Deposit',
      'date': DateTime.now().toIso8601String(),
    });
    await db.insert('transactions', {
      'currency': 'SYP',
      'amount': -100000,
      'type': 'Withdrawal',
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<void> insert(String table, Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await instance.database;
    return await db.query(table);
  }

  Future<void> update(String table, Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await instance.database;
    return await db.query(table, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await instance.database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<Map<String, dynamic>> exportData() async {
    final db = await instance.database;

    // Fetch all data from each table
    final cashbox = await db.query('cashbox');
    final transactions = await db.query('transactions');
    final debts = await db.query('debts');
    final settings = await db.query('settings');
    final tanks = await db.query('tanks'); // Add tanks table
    final pumps = await db.query('pumps'); // Add pumps table

    // Combine into a single JSON object
    return {
      'cashbox': cashbox,
      'transactions': transactions,
      'debts': debts,
      'settings': settings,
      'tanks': tanks, // Include tanks
      'pumps': pumps, // Include pumps
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final db = await instance.database;

    // Clear existing data
    await db.delete('cashbox');
    await db.delete('transactions');
    await db.delete('debts');
    await db.delete('settings');
    await db.delete('tanks');
    await db.delete('pumps');

    // Insert new data
    try {
      if (data['cashbox'] != null) {
        for (var row in data['cashbox']) {
          print('Inserting into cashbox: $row'); // Log each row
          await db.insert('cashbox', row);
        }
      }
      if (data['transactions'] != null) {
        for (var row in data['transactions']) {
          print('Inserting into transactions: $row'); // Log each row
          await db.insert('transactions', row);
        }
      }
      if (data['debts'] != null) {
        for (var row in data['debts']) {
          print('Inserting into debts: $row'); // Log each row
          await db.insert('debts', row);
        }
      }
      if (data['settings'] != null) {
        for (var row in data['settings']) {
          print('Inserting into settings: $row'); // Log each row
          await db.insert('settings', row);
        }
      }
      if (data['tanks'] != null) {
        for (var row in data['tanks']) {
          print('Inserting into tanks: $row'); // Log each row
          await db.insert('tanks', row);
        }
      }
      if (data['pumps'] != null) {
        for (var row in data['pumps']) {
          print('Inserting into pumps: $row'); // Log each row
          await db.insert('pumps', row);
        }
      }
    } catch (e) {
      // Rollback in case of failure
      await db.delete('cashbox');
      await db.delete('transactions');
      await db.delete('debts');
      await db.delete('settings');
      await db.delete('tanks');
      await db.delete('pumps');
      print('Rollback due to error: $e'); // Log the rollback
      throw Exception('Failed to restore data: $e');
    }
  }

  Future<void> saveBackupToFile(Map<String, dynamic> data) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/backup.json');
    await file.writeAsString(jsonEncode(data));
  }

  Future<Map<String, dynamic>> loadBackupFromFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/backup.json');
    print('Backup file path: ${file.path}'); // Log the file path

    if (!await file.exists()) {
      throw Exception('Backup file not found.');
    }

    final content = await file.readAsString();
    print('Backup file content: $content'); // Log the file content

    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<void> insertOrUpdateCashbox(Cashbox cashbox) async {
    final db = await database; // Ensure you have a `database` getter
    final existingCashbox = await db.query('cashbox');

    if (existingCashbox.isEmpty) {
      // Insert new cashbox
      await db.insert('cashbox', cashbox.toMap());
    } else {
      // Update existing cashbox
      await db.update(
        'cashbox',
        cashbox.toMap(),
        where: 'id = ?',
        whereArgs: [1], // Assuming there's only one cashbox record
      );
    }
  }
}
