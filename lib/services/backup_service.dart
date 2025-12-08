import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import '../data/models.dart';
import '../providers.dart';

class BackupService {
  final WidgetRef ref;
  final BuildContext context;

  BackupService(this.context, this.ref);

  // ==============================================================================
  // 1. NATIVE EXPORT (Creates ZIP with Vehicles.csv and service_record.csv)
  // ==============================================================================
  Future<void> createBackup() async {
    try {
      final db = ref.read(databaseProvider);
      final vehicles = await db.getAllVehicles();
      final records = await db.getAllServiceRecords();

      if (vehicles.isEmpty) {
        _showSnack('No data to backup!', isError: true);
        return;
      }

      // --- A. Generate Vehicles.csv ---
      List<List<dynamic>> vRows = [];
      vRows.add(['VehicleName', 'Make', 'Model', 'CurrentODO', 'Offset']); // Header
      
      for (var v in vehicles) {
        vRows.add([v.name, v.make, v.model, v.currentOdo, v.odoOffset]);
      }
      String vehiclesCsv = const ListToCsvConverter().convert(vRows);

      // --- B. Generate service_record.csv ---
      List<List<dynamic>> sRows = [];
      sRows.add(['VehicleName', 'Date', 'Type', 'Cost', 'Odometer', 'Notes']); // Header

      for (var r in records) {
        final vehicle = vehicles.firstWhere((v) => v.id == r.vehicleId, orElse: () => Vehicle(name: 'Unknown', make: '', currentOdo: 0));
        sRows.add([
          vehicle.name,
          DateFormat('yyyy-MM-dd').format(r.date),
          r.serviceType,
          r.cost,
          r.odoReading,
          r.notes
        ]);
      }
      String serviceCsv = const ListToCsvConverter().convert(sRows);

      // --- C. Zip It ---
      final archive = Archive();
      archive.addFile(ArchiveFile('Vehicles.csv', vehiclesCsv.length, utf8.encode(vehiclesCsv)));
      archive.addFile(ArchiveFile('service_record.csv', serviceCsv.length, utf8.encode(serviceCsv)));

      final encodedZip = ZipEncoder().encode(archive);
      if (encodedZip == null) throw Exception('Failed to encode ZIP');

      // --- D. Save & Share ---
      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final zipFile = File('${directory.path}/vmt_backup_$dateStr.zip');
      await zipFile.writeAsBytes(encodedZip);

      await Share.shareXFiles([XFile(zipFile.path)], text: 'My Garage Native Backup');

    } catch (e) {
      _showSnack('Backup failed: $e', isError: true);
    }
  }

  // ==============================================================================
  // 2. NATIVE RESTORE (Reads specific Native ZIP format)
  // ==============================================================================
  Future<void> restoreBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
      );

      if (result == null) return;

      final File zipFile = File(result.files.single.path!);
      final bytes = await zipFile.readAsBytes();
      final Archive archive = ZipDecoder().decodeBytes(bytes);

      String? vehiclesCsvContent;
      String? serviceCsvContent;

      for (final file in archive) {
        if (!file.isFile) continue;
        final filename = file.name.toLowerCase();
        
        if (filename.endsWith('vehicles.csv')) {
          vehiclesCsvContent = utf8.decode(file.content as List<int>);
        } else if (filename.endsWith('service_record.csv')) {
          serviceCsvContent = utf8.decode(file.content as List<int>);
        }
      }

      if (vehiclesCsvContent == null || serviceCsvContent == null) {
        _showSnack('Invalid Backup File: Missing required CSVs.', isError: true);
        return;
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore Backup?'),
            content: const Text('This will merge the backup data into your app.\n\nNote: This feature is for restoring backups created by THIS app.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _processNativeRestore(vehiclesCsvContent!, serviceCsvContent!);
                },
                child: const Text('Restore'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      _showSnack('Restore failed: $e', isError: true);
    }
  }

  Future<void> _processNativeRestore(String vInput, String sInput) async {
    final db = ref.read(databaseProvider);
    int importedCount = 0;

    // --- 1. Restore Vehicles ---
    // 👇 FIXED: Removed eol: '\n' to allow auto-detection of line endings
    List<List<dynamic>> vRows = const CsvToListConverter(shouldParseNumbers: false).convert(vInput);
    Map<String, int> vehicleIdMap = {};

    // Skip Header (i=1)
    for (var i = 1; i < vRows.length; i++) {
      final row = vRows[i];
      if (row.length < 4) continue;

      String name = row[0].toString().trim();
      String make = row[1].toString().trim();
      String model = row[2].toString().trim();
      int odo = int.tryParse(row[3].toString()) ?? 0;
      int offset = (row.length > 4) ? (int.tryParse(row[4].toString()) ?? 0) : 0;

      var existing = await db.getAllVehicles();
      var match = existing.where((v) => v.name == name);

      if (match.isNotEmpty) {
        vehicleIdMap[name] = match.first.id!;
      } else {
        final newId = await db.insertVehicle(Vehicle(
          name: name, make: make, model: model, currentOdo: odo, odoOffset: offset
        ));
        vehicleIdMap[name] = newId;
      }
    }

    // --- 2. Restore Records ---
    // 👇 FIXED: Removed eol: '\n'
    List<List<dynamic>> sRows = const CsvToListConverter(shouldParseNumbers: false).convert(sInput);
    
    // Skip Header (i=1)
    for (var i = 1; i < sRows.length; i++) {
      final row = sRows[i];
      if (row.length < 5) continue;

      String vName = row[0].toString().trim();
      int? vehicleId = vehicleIdMap[vName];
      if (vehicleId == null) continue;

      DateTime date;
      try { date = DateTime.parse(row[1].toString()); } catch (_) { date = DateTime.now(); }
      
      String type = row[2].toString();
      double cost = double.tryParse(row[3].toString()) ?? 0.0;
      int odo = int.tryParse(row[4].toString()) ?? 0;
      String notes = (row.length > 5) ? row[5].toString() : '';

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
    _showSnack('Restored $importedCount records successfully!');
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
      );
    }
  }
}