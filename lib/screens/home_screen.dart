import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../data/database.dart';
import '../data/models.dart';
import 'vehicle_details_screen.dart';
import 'expense_report_screen.dart';
import 'import_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleListAsync = ref.watch(vehicleListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Garage'),
        actions: [
          // 1. IMPORT BUTTON (New)
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import CSV',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              );
            },
          ),
          // 2. EXPENSE REPORT BUTTON (Existing)
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
            return _buildEmptyState();
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
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVehicleDialog(context, ref),
        label: const Text('Add Vehicle'),
        icon: const Icon(Icons.add_circle_outline),
      ),
    );
  }

  Widget _buildEmptyState() {
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
          const Text('Add a vehicle to start tracking'),
        ],
      ),
    );
  }
  
  // Re-use your existing _showAddVehicleDialog function here
  // (Paste the function from the previous step here)
  void _showAddVehicleDialog(BuildContext context, WidgetRef ref) {
     // ... (Keep your existing dialog code, it works fine!)
     // For brevity, I assume you still have the dialog code. 
     // Let me know if you need it pasted again.
     final nameController = TextEditingController();
    final makeController = TextEditingController();
    final modelController = TextEditingController();
    final odoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Vehicle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nickname', prefixIcon: Icon(Icons.abc))),
              TextField(controller: makeController, decoration: const InputDecoration(labelText: 'Make', prefixIcon: Icon(Icons.branding_watermark))),
              TextField(controller: modelController, decoration: const InputDecoration(labelText: 'Model', prefixIcon: Icon(Icons.car_repair))),
              TextField(controller: odoController, decoration: const InputDecoration(labelText: 'Current ODO', prefixIcon: Icon(Icons.speed)), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              final newVehicle = Vehicle(
                name: nameController.text,
                make: makeController.text,
                model: modelController.text,
                currentOdo: int.tryParse(odoController.text) ?? 0,
              );
              await db.insertVehicle(newVehicle);
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

  const _VehicleCard({required this.vehicle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.speed, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${vehicle.currentOdo} km', 
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}