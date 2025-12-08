import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'models.dart';

class AppDatabase {
  // Singleton instance
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  Database? _db;

  // Define the "Stores" (like Tables)
  final _vehicleStore = intMapStoreFactory.store('vehicles');
  final _serviceStore = intMapStoreFactory.store('service_records');

  // Open the database
  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'vmt.db');
    _db = await databaseFactoryIo.openDatabase(dbPath);
    return _db!;
  }

  // --- Vehicle Operations ---

  Future<int> insertVehicle(Vehicle vehicle) async {
    final db = await database;
    return await _vehicleStore.add(db, vehicle.toMap());
  }

  Future<List<Vehicle>> getAllVehicles() async {
    final db = await database;
    // Sembast: Finder is like a Query
    final snapshots = await _vehicleStore.find(db);
    
    return snapshots.map((snapshot) {
      return Vehicle.fromMap(snapshot.key, snapshot.value);
    }).toList();
  }

  // --- Service Record Operations ---

  Future<int> insertServiceRecord(ServiceRecord record) async {
    final db = await database;
    return await _serviceStore.add(db, record.toMap());
  }

  Future<List<ServiceRecord>> getRecordsForVehicle(int vehicleId) async {
    final db = await database;
    final finder = Finder(
      filter: Filter.equals('vehicleId', vehicleId),
      sortOrders: [SortOrder('date', false)], // Sort by date descending
    );

    final snapshots = await _serviceStore.find(db, finder: finder);
    return snapshots.map((s) => ServiceRecord.fromMap(s.key, s.value)).toList();
  }


// --- Update & Delete Service Records ---

  Future<void> updateServiceRecord(ServiceRecord record) async {
    final db = await database;
    final finder = Finder(filter: Filter.byKey(record.id));
    await _serviceStore.update(db, record.toMap(), finder: finder);
  }

  Future<void> deleteServiceRecord(int id) async {
    final db = await database;
    final finder = Finder(filter: Filter.byKey(id));
    await _serviceStore.delete(db, finder: finder);
  }

// Updates an existing vehicle (matches by ID)
  Future<void> updateVehicle(Vehicle vehicle) async {
    final db = await database;
    final finder = Finder(filter: Filter.byKey(vehicle.id));
    await _vehicleStore.update(db, vehicle.toMap(), finder: finder);
  }

  // --- Expense Report Queries ---
  Future<List<ServiceRecord>> getAllServiceRecords() async {
    final db = await database;
    // Sort by Date (Newest first)
    final finder = Finder(sortOrders: [SortOrder('date', false)]);
    final snapshots = await _serviceStore.find(db, finder: finder);
    return snapshots.map((s) => ServiceRecord.fromMap(s.key, s.value)).toList();
  }

  // --- NUKE DATA (FOR TESTING) ---
  Future<void> deleteAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await _vehicleStore.delete(txn);
      await _serviceStore.delete(txn);
    });
  }

}
