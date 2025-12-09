import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers.dart';
import '../data/database.dart';
import '../data/models.dart';
import 'vehicle_details_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleListAsync = ref.watch(vehicleListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Vehicle Maintenance Tracker'),
        centerTitle: true,
      ),
      body: vehicleListAsync.when(
        data: (vehicles) {
          if (vehicles.isEmpty) return _buildEmptyState(context, ref);
          
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            separatorBuilder: (c, i) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _HeroVehicleCard(
                vehicle: vehicles[index],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleDetailsScreen(vehicle: vehicles[index]))),
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
        label: const Text('Add Ride'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(FontAwesomeIcons.warehouse, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text('Garage Empty', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => _showVehicleDialog(context, ref), child: const Text('Park your first vehicle')),
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
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: makeController, decoration: const InputDecoration(labelText: 'Make'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: modelController, decoration: const InputDecoration(labelText: 'Model'))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: odoController, decoration: const InputDecoration(labelText: 'Current ODO', suffixText: 'km'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: offsetController, decoration: const InputDecoration(labelText: 'Offset (Optional)', helperText: 'If speedometer was replaced'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
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
              if (isEdit) await db.updateVehicle(vehicle);
              else await db.insertVehicle(vehicle);
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

class _HeroVehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _HeroVehicleCard({required this.vehicle, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    // Detect Dark Mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0, // Flat look
      // 👇 CUSTOM COLOR LOGIC: 
      // Dark Mode: Dark Slate Grey (popping against black)
      // Light Mode: Pure White
      color: isDark ? const Color(0xFF25282B) : Colors.white,
      
      // 👇 BORDER LOGIC: Subtle border for definition
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
          width: 1,
        ),
      ),
      
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Name + Edit
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      vehicle.name, 
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        color: Theme.of(context).colorScheme.onSurface
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit), 
                    onPressed: onEdit,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Bottom Row: ODO Chip
              Row(
                children: [
                  _InfoChip(icon: Icons.speed, label: '${vehicle.currentOdo} km'),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        // Use a Surface Container color for the chip background
        color: Theme.of(context).colorScheme.surfaceContainerHighest, 
        borderRadius: BorderRadius.circular(20)
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant
            )
          ),
        ],
      ),
    );
  }
}