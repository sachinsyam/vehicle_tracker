import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/database.dart';
import 'data/models.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

// Simple FutureProvider to fetch the list once (or refresh manually)
final vehicleListProvider = FutureProvider<List<Vehicle>>((ref) async {
  final db = ref.read(databaseProvider);
  return await db.getAllVehicles();
});
// Fetch service records for a specific vehicle ID
// .family lets us pass the 'vehicleId' as an argument
final serviceRecordsProvider = FutureProvider.family<List<ServiceRecord>, int>((ref, vehicleId) async {
  final db = ref.read(databaseProvider);
  return db.getRecordsForVehicle(vehicleId);
});

// Fetch ALL records for the expense report
final allExpensesProvider = FutureProvider<List<ServiceRecord>>((ref) async {
  final db = ref.read(databaseProvider);
  return db.getAllServiceRecords();
});