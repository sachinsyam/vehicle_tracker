import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vehicle_tracker/screens/vehicle_details_screen.dart';
import '../providers.dart';
import '../data/database.dart';
import '../data/models.dart';

// We use ConsumerWidget because we need to read data from Riverpod
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This watches the vehicle list. 
    // AsyncValue handles loading, error, and data states automatically.
    final vehicleListAsync = ref.watch(vehicleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // The body handles 3 states: Data, Loading, Error
      body: vehicleListAsync.when(
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return const Center(child: Text('No vehicles added yet.'));
          }
          // List of vehicles
          return ListView.builder(
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return ListTile(
                leading: const Icon(Icons.directions_car),
                title: Text(vehicle.name),
                subtitle: Text('${vehicle.make} ${vehicle.model ?? ""}'),
                trailing: Text('${vehicle.currentOdo} km'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VehicleDetailsScreen(vehicle: vehicle),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      
      // Button to add a new vehicle
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // We will create the "Add Vehicle" logic next
          _showAddVehicleDialog(context, ref); 
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // A simple temporary popup to add a vehicle to test the DB
  void _showAddVehicleDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final makeController = TextEditingController();
    final odoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Vehicle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nickname (e.g. My Bike)')),
            TextField(controller: makeController, decoration: const InputDecoration(labelText: 'Make (e.g. Honda)')),
            TextField(controller: odoController, decoration: const InputDecoration(labelText: 'Current ODO'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              
              final newVehicle = Vehicle(
                name: nameController.text,
                make: makeController.text,
                currentOdo: int.tryParse(odoController.text) ?? 0,
                // ID is null because DB generates it
              );

              await db.insertVehicle(newVehicle);
              
              // Refresh the list to show the new item
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