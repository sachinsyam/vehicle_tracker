import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../data/models.dart';
import 'vehicle_details_screen.dart';
import 'expense_report_screen.dart';
import 'import_screen.dart';
import 'about_screen.dart';
import '../services/backup_service.dart';
import '../services/migration_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleListAsync = ref.watch(vehicleListProvider);

    return Scaffold(
      // 👇 CHANGED: Light Grey background makes white cards pop
      backgroundColor: Colors.grey.shade200, 
      appBar: AppBar(
        title: const Text('My Garage'),
        backgroundColor: Colors.transparent, // Optional: Makes AppBar blend better
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              final backupService = BackupService(context, ref);
              final migrationService = MigrationService(context, ref);

              if (value == 'backup') {
                backupService.createBackup();
              } else if (value == 'restore') {
                backupService.restoreBackup();
              } else if (value == 'migrate') {
                migrationService.importFromZip();
              } else if (value == 'about') {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const AboutScreen())
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [Icon(Icons.save_alt, color: Colors.blue), SizedBox(width: 10), Text('Backup Data')],
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [Icon(Icons.restore_page, color: Colors.green), SizedBox(width: 10), Text('Restore Backup')],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'migrate',
                child: Row(
                  children: [Icon(Icons.move_to_inbox, color: Colors.orange), SizedBox(width: 10), Text('Migrate from Simply Auto')],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [Icon(Icons.info_outline, color: Colors.grey), SizedBox(width: 10), Text('About')],
                ),
              ),
            ],
          ),
          
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Single CSV',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              );
            },
          ),
          
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Expense Report',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseReportScreen()),
              );
            },
          ),
        ],
      ),

      body: vehicleListAsync.when(
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return _buildEmptyState(context, ref);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _VehicleCard(
                vehicle: vehicles[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VehicleDetailsScreen(vehicle: vehicles[index])),
                ),
                onEdit: () => _showVehicleDialog(context, ref, vehicleToEdit: vehicles[index]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVehicleDialog(context, ref),
        label: const Text('Add Vehicle'),
        icon: const Icon(Icons.add_circle_outline),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.garage_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Your garage is empty',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _showVehicleDialog(context, ref), 
            child: const Text('Add a vehicle now')
          ),
        ],
      ),
    );
  }
  
  void _showVehicleDialog(BuildContext context, WidgetRef ref, {Vehicle? vehicleToEdit}) {
    final isEdit = vehicleToEdit != null;
    
    final nameController = TextEditingController(text: isEdit ? vehicleToEdit.name : '');
    final makeController = TextEditingController(text: isEdit ? vehicleToEdit.make : '');
    final modelController = TextEditingController(text: isEdit ? vehicleToEdit.model : '');
    final odoController = TextEditingController(text: isEdit ? vehicleToEdit.currentOdo.toString() : '');
    final offsetController = TextEditingController(text: isEdit ? vehicleToEdit.odoOffset.toString() : '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Vehicle' : 'Add Vehicle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nickname', prefixIcon: Icon(Icons.abc))),
              TextField(controller: makeController, decoration: const InputDecoration(labelText: 'Make', prefixIcon: Icon(Icons.branding_watermark))),
              TextField(controller: modelController, decoration: const InputDecoration(labelText: 'Model', prefixIcon: Icon(Icons.car_repair))),
              TextField(controller: odoController, decoration: const InputDecoration(labelText: 'Current ODO', prefixIcon: Icon(Icons.speed)), keyboardType: TextInputType.number),
              
              const SizedBox(height: 10),
              TextField(
                controller: offsetController, 
                decoration: const InputDecoration(
                  labelText: 'ODO Offset (Optional)', 
                  prefixIcon: Icon(Icons.exposure_plus_1),
                  helperText: 'Added to dashboard reading automatically',
                ), 
                keyboardType: TextInputType.number
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              
              final vehicle = Vehicle(
                id: isEdit ? vehicleToEdit.id : null, 
                name: nameController.text,
                make: makeController.text,
                model: modelController.text,
                currentOdo: int.tryParse(odoController.text) ?? 0,
                odoOffset: int.tryParse(offsetController.text) ?? 0, 
              );

              if (isEdit) {
                await db.updateVehicle(vehicle);
              } else {
                await db.insertVehicle(vehicle);
              }
              
              ref.refresh(vehicleListProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _VehicleCard({required this.vehicle, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2, // Slight elevation makes it stand out on grey
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white, // Ensure card is white
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_car_filled, 
                  color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              // Text Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.name, 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${vehicle.make} ${vehicle.model}',
                      style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              // ODO Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text('${vehicle.currentOdo} km', 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              // Edit Button
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}