import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:archive/archive.dart';
import '../data/models.dart';
import '../providers.dart';

class MigrationService {
  final WidgetRef ref;
  final BuildContext context;

  MigrationService(this.context, this.ref);

  Future<void> importFromZip() async {
    try {
      // 1. Pick ZIP File
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
      );

      if (result == null) return;

      final File zipFile = File(result.files.single.path!);
      final bytes = await zipFile.readAsBytes();

      // 2. Decode the ZIP
      final Archive archive = ZipDecoder().decodeBytes(bytes);

      String? vehiclesCsvContent;
      String? fuelLogCsvContent;

      // 3. Search for the required files inside the ZIP
      for (final file in archive) {
        if (!file.isFile) continue;
        
        final filename = file.name.toLowerCase();
        
        // Convert content to String
        if (filename.endsWith('vehicles.csv')) {
          vehiclesCsvContent = utf8.decode(file.content as List<int>);
        } else if (filename.endsWith('fuel_log.csv')) {
          fuelLogCsvContent = utf8.decode(file.content as List<int>);
        }
      }

      if (vehiclesCsvContent == null || fuelLogCsvContent == null) {
        _showSnack('Invalid Backup: Could not find Vehicles.csv or Fuel_Log.csv inside the ZIP.', isError: true);
        return;
      }

      // 4. Process the extracted CSV strings
      await _processImport(vehiclesCsvContent, fuelLogCsvContent);

    } catch (e) {
      _showSnack('Migration failed: $e', isError: true);
    }
  }

  Future<void> _processImport(String vInput, String fInput) async {
    final db = ref.read(databaseProvider);
    
    // --- STEP A: Parse Vehicles ---
    List<List<dynamic>> vRows = const CsvToListConverter().convert(vInput, eol: '\n');
    
    // Map to link "Legacy Nickname" -> "New Database ID"
    Map<String, int> vehicleIdMap = {}; 
    int vehiclesAdded = 0;

    if (vRows.isEmpty) throw Exception('Vehicles.csv is empty');
    
    // Detect Headers
    final vHeaders = vRows[0].map((e) => e.toString().trim()).toList();
    final idxMake = vHeaders.indexOf('Make');
    final idxModel = vHeaders.indexOf('Model');
    final idxName = vHeaders.indexOf('Vehicle ID'); // This is the Nickname

    if (idxName == -1) throw Exception('Invalid Vehicles.csv format: Missing "Vehicle ID" column');

    for (var i = 1; i < vRows.length; i++) {
      final row = vRows[i];
      if (row.length < idxName + 1) continue;
      
      String name = row[idxName].toString().trim();
      // Skip template/empty rows
      if (name.toLowerCase() == 'nickname' || name == 'vehicle name' || name.isEmpty) continue;

      String make = idxMake != -1 ? row[idxMake].toString() : '';
      String model = idxModel != -1 ? row[idxModel].toString() : '';

      // Check existence
      var existing = await db.getAllVehicles();
      var match = existing.where((v) => v.name == name);
      
      if (match.isNotEmpty) {
        vehicleIdMap[name] = match.first.id!;
      } else {
        final newId = await db.insertVehicle(Vehicle(
          name: name,
          make: make.isEmpty ? 'Imported' : make,
          model: model,
          currentOdo: 0, 
        ));
        vehicleIdMap[name] = newId;
        vehiclesAdded++;
      }
    }

    // --- STEP B: Parse Service Logs ---
    List<List<dynamic>> fRows = const CsvToListConverter().convert(fInput, eol: '\n');
    
    if (fRows.isEmpty) throw Exception('Fuel_Log.csv is empty');
    final fHeaders = fRows[0].map((e) => e.toString().trim()).toList();
    
    // Map Columns
    final idxVName = fHeaders.indexOf('Vehicle ID'); // Nickname in Log
    final idxOdo = fHeaders.indexOf('Odometer');
    final idxCost = fHeaders.indexOf('Total Cost');
    final idxStation = fHeaders.indexOf('Filling Station');
    final idxNotes = fHeaders.indexOf('Notes');
    final idxDay = fHeaders.indexOf('Day');
    final idxMonth = fHeaders.indexOf('Month');
    final idxYear = fHeaders.indexOf('Year');
    final idxDesc = fHeaders.indexOf('Record Desc');

    int recordsAdded = 0;

    for (var i = 1; i < fRows.length; i++) {
      final row = fRows[i];
      if (row.length < idxVName + 1) continue;

      String vName = row[idxVName].toString().trim();
      if (vName == 'vehicle name') continue; 

      int? vehicleId = vehicleIdMap[vName];
      if (vehicleId == null) continue; // Skip orphan records

      // Date Parsing
      int y = int.tryParse(row[idxYear].toString()) ?? DateTime.now().year;
      int m = int.tryParse(row[idxMonth].toString()) ?? 1;
      int d = int.tryParse(row[idxDay].toString()) ?? 1;
      DateTime date = DateTime(y, m, d);

      // --- SIMPLIFIED NUMERIC PARSING ---
      
      // Cost: Handle commas, default to 0.0
      String costStr = row[idxCost].toString().replaceAll(',', '').trim();
      double cost = double.tryParse(costStr) ?? 0.0;

      // ODO: Handle commas, treat as direct integer
      // We also handle the edge case where CSV might export "12000.0" as a string
      String odoStr = row[idxOdo].toString().replaceAll(',', '').trim();
      if (odoStr.endsWith('.0')) {
        odoStr = odoStr.substring(0, odoStr.length - 2);
      }
      int odo = int.tryParse(odoStr) ?? 0;

      // Type Logic
      String typeRaw = row[idxDesc].toString().trim();
      String serviceType = typeRaw;
      if (typeRaw.toLowerCase().contains('adhoc')) {
        serviceType = 'ODO Update';
        cost = 0; 
      }

      // Note Construction
      List<String> noteParts = [];
      
      String originalNote = row[idxNotes].toString().trim();
      if (originalNote.isNotEmpty && originalNote != 'notes of service') {
        noteParts.add(originalNote);
      }
      
      String station = row[idxStation].toString().trim();
      if (station.isNotEmpty && station != 'service shop name') {
        noteParts.add("Station: $station");
      }

      // Handle Extra Columns
      int startExtra = idxDesc + 1;
      for (int k = startExtra; k < row.length; k++) {
        String extra = row[k].toString().trim();
        if (extra.isNotEmpty && extra != 'null') {
          noteParts.add(extra);
        }
      }

      String finalNotes = noteParts.join('\n');

      // Insert
      await db.insertServiceRecord(ServiceRecord(
        vehicleId: vehicleId,
        date: date,
        serviceType: serviceType,
        cost: cost,
        odoReading: odo,
        notes: finalNotes,
      ));
      
      // Smart ODO Update
      final v = await db.getAllVehicles();
      final currentV = v.firstWhere((e) => e.id == vehicleId);
      if (odo > currentV.currentOdo) {
        await db.updateVehicle(Vehicle(
          id: currentV.id, 
          name: currentV.name, 
          make: currentV.make, 
          model: currentV.model, 
          currentOdo: odo,
          odoOffset: currentV.odoOffset
        ));
      }
      
      recordsAdded++;
    }

    ref.refresh(vehicleListProvider);
    ref.refresh(allExpensesProvider);
    _showSnack('Success! Imported $vehiclesAdded vehicles and $recordsAdded records.');
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
      );
    }
  }
}