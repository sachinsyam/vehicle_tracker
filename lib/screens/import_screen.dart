import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../providers.dart';
import '../data/database.dart';
import '../data/models.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  int? _selectedVehicleId;
  bool _isImporting = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehicleListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Import Data')),
      body: vehiclesAsync.when(
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return const Center(child: Text('Please add a vehicle first.'));
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. INSTRUCTIONS
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(height: 8),
                      Text(
                        'CSV Format Required:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Date, Type, Cost, ODO, Notes (Optional)'),
                      SizedBox(height: 4),
                      Text('Example: 2023-01-01, Engine Oil, 1200, 5000, Shell Synthetic',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // 2. VEHICLE DROPDOWN
                const Text('Select Target Vehicle:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _selectedVehicleId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text('Choose a vehicle...'),
                  items: vehicles.map((v) {
                    return DropdownMenuItem<int>(
                      value: v.id,
                      child: Text('${v.make} ${v.model} (${v.name})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedVehicleId = val);
                  },
                ),

                const SizedBox(height: 30),

                // 3. IMPORT BUTTON
                ElevatedButton.icon(
                  onPressed: (_selectedVehicleId == null || _isImporting) 
                      ? null 
                      : () => _pickAndImportCsv(context, ref),
                  icon: _isImporting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_file),
                  label: Text(_isImporting ? 'Importing...' : 'Select CSV File'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),
                
                // 4. STATUS MESSAGE
                if (_statusMessage.isNotEmpty)
                  Center(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _statusMessage.contains('Error') ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _pickAndImportCsv(BuildContext context, WidgetRef ref) async {
    setState(() {
      _isImporting = true;
      _statusMessage = '';
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        
        // Read file
        final input = file.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();

        final db = ref.read(databaseProvider);
        int importCount = 0;

        // Skip Header Row (Start at i=1)
        for (var i = 1; i < fields.length; i++) {
final row = fields[i];
          // We need at least 6 columns (ODO, Cost, D, M, Y, Type)
          if (row.length < 6) continue; 

          // 1. Parse ODO (Column 0)
          int odo = int.tryParse(row[0].toString()) ?? 0;

          // 2. Parse Cost (Column 1)
          double cost = double.tryParse(row[1].toString()) ?? 0.0;

          // 3. Construct Date from D, M, Y (Columns 2, 3, 4)
          int d = int.tryParse(row[2].toString()) ?? 1;
          int m = int.tryParse(row[3].toString()) ?? 1;
          int y = int.tryParse(row[4].toString()) ?? 2000;
          DateTime date = DateTime(y, m, d);

          // 4. Parse Service Type (Column 5)
          String type = row[5].toString();

          // 5. Parse Notes (Column 6 - Optional)
          String notes = '';
          if (row.length > 6) {
            notes = row[6].toString();
          }

          // Create Record
          final record = ServiceRecord(
            vehicleId: _selectedVehicleId!,
            date: date,
            serviceType: type,
            cost: cost,
            odoReading: odo,
            notes: notes,
          );

          await db.insertServiceRecord(record);
          importCount++;
        }

        // Force Refresh of providers so screens update immediately
        ref.refresh(serviceRecordsProvider(_selectedVehicleId!));
        ref.refresh(allExpensesProvider);
        ref.refresh(vehicleListProvider);

        if (mounted) {
          setState(() {
            _statusMessage = 'Success! Imported $importCount records.';
            _isImporting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Imported $importCount records successfully!')),
          );
        }
      } else {
        setState(() {
          _isImporting = false;
          _statusMessage = 'Cancelled.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
          _isImporting = false;
        });
      }
    }
  }
}