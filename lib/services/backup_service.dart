import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../providers.dart';

class BackupService {
  final WidgetRef ref;
  final BuildContext context;

  BackupService(this.context, this.ref);

  // --- 1. EXPORT TO CSV (Backup) ---
  Future<void> createBackup() async {
    try {
      final db = ref.read(databaseProvider);
      final vehicles = await db.getAllVehicles(); // You need to ensure this method exists in database.dart
      final records = await db.getAllServiceRecords();

      if (vehicles.isEmpty) {
        _showSnack('No data to backup!', isError: true);
        return;
      }

      // 1. Build CSV Rows
      List<List<dynamic>> rows = [];
      
      // Header
      rows.add(['VehicleName', 'Date', 'ServiceType', 'Cost', 'ODO', 'Notes']);

      // Data
      for (var record in records) {
        // Find vehicle name for this record
        final vehicle = vehicles.firstWhere(
          (v) => v.id == record.vehicleId, 
          orElse: () => Vehicle(name: 'Unknown', make: '', currentOdo: 0)
        );
        
        rows.add([
          vehicle.name,
          DateFormat('yyyy-MM-dd').format(record.date),
          record.serviceType,
          record.cost,
          record.odoReading,
          record.notes
        ]);
      }

      // 2. Convert to String
      String csvData = const ListToCsvConverter().convert(rows);

      // 3. Save to Temp File
      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final file = File('${directory.path}/vmt_backup_$dateStr.csv');
      await file.writeAsString(csvData);

      // 4. Share (This allows "Save to Drive" or "Save to Files")
      await Share.shareXFiles(
        [XFile(file.path)], 
        text: 'My Vehicle Tracker Backup'
      );

    } catch (e) {
      _showSnack('Backup failed: $e', isError: true);
    }
  }

  // --- 2. RESTORE FROM CSV ---
  Future<void> restoreBackup() async {
    try {
      // 1. Pick File
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();

        if (fields.length < 2) {
          _showSnack('Empty or invalid CSV file.', isError: true);
          return;
        }

        // 2. Show Confirmation
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Restore Data?'),
              content: const Text('This will merge the CSV data into your app.\nExisting data will NOT be deleted, but duplicates might occur if you restore twice.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _processRestore(fields);
                  },
                  child: const Text('Restore'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      _showSnack('Restore failed: $e', isError: true);
    }
  }

  Future<void> _processRestore(List<List<dynamic>> rows) async {
    final db = ref.read(databaseProvider);
    final existingVehicles = await db.getAllVehicles();
    int importedCount = 0;

    // Skip Header (i=1)
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 6) continue;

      String vName = row[0].toString();
      String dateStr = row[1].toString();
      String type = row[2].toString();
      double cost = double.tryParse(row[3].toString()) ?? 0.0;
      int odo = int.tryParse(row[4].toString()) ?? 0;
      String notes = row[5].toString();

      // 1. Find or Create Vehicle
      // We assume the user creates vehicles by Name.
      // If "Honda CBR" exists, use it. If not, create it.
      int vehicleId;
      var match = existingVehicles.where((v) => v.name == vName);
      
      if (match.isNotEmpty) {
        vehicleId = match.first.id!;
      } else {
        // Create new vehicle if it doesn't exist
        final newId = await db.insertVehicle(Vehicle(
          name: vName, 
          make: 'Imported', 
          model: '', 
          currentOdo: odo
        ));
        vehicleId = newId;
        // Add to local list cache so we don't create it again in this loop
        existingVehicles.add(Vehicle(id: newId, name: vName, make: 'Imported', model: '', currentOdo: odo));
      }

      // 2. Insert Record
      DateTime date;
      try { date = DateTime.parse(dateStr); } catch (_) { date = DateTime.now(); }

      await db.insertServiceRecord(ServiceRecord(
        vehicleId: vehicleId,
        date: date,
        serviceType: type,
        cost: cost,
        odoReading: odo,
        notes: notes,
      ));
      importedCount++;
    }

    ref.refresh(vehicleListProvider);
    ref.refresh(allExpensesProvider);
    _showSnack('Restored $importedCount records!');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }
}