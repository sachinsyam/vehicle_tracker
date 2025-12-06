import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../data/database.dart';
import '../data/models.dart';

class VehicleDetailsScreen extends ConsumerWidget {
  final Vehicle vehicle;

  const VehicleDetailsScreen({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(serviceRecordsProvider(vehicle.id!));

    return Scaffold(
      appBar: AppBar(
        title: Text(vehicle.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Header Stats
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade200,
            width: double.infinity,
            child: Column(
              children: [
                Text('Current ODO: ${vehicle.currentOdo} km',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${vehicle.make} ${vehicle.model}'),
              ],
            ),
          ),

          // The List
          Expanded(
            child: recordsAsync.when(
              data: (records) {
                if (records.isEmpty) return const Center(child: Text('No service history yet.'));

                return ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.build, color: Colors.blue),
                      ),
                      title: Text(record.serviceType, style: const TextStyle(fontWeight: FontWeight.bold)),
                      // Display Date, Cost, and ODO in the subtitle for a clean look
                      subtitle: Text(
                        '${DateFormat('MMM dd, yyyy').format(record.date)}\n₹${record.cost.toStringAsFixed(0)} • ${record.odoReading} km',
                        style: const TextStyle(height: 1.5),
                      ),
                      isThreeLine: true, // Allows subtitle to take 2 lines
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showServiceDialog(context, ref, recordToEdit: record);
                          } else if (value == 'delete') {
                            _confirmDelete(context, ref, record.id!);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [Icon(Icons.edit, color: Colors.green), SizedBox(width: 8), Text('Edit')],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete')],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showServiceDialog(context, ref),
        label: const Text('Add Service'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  // Handle Delete
  void _confirmDelete(BuildContext context, WidgetRef ref, int recordId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.deleteServiceRecord(recordId);
              ref.refresh(serviceRecordsProvider(vehicle.id!));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Combined Dialog for Add AND Edit
  void _showServiceDialog(BuildContext context, WidgetRef ref, {ServiceRecord? recordToEdit}) {
    final isEdit = recordToEdit != null;
    
    // Pre-fill controllers if editing
    final typeController = TextEditingController(text: isEdit ? recordToEdit.serviceType : '');
    final costController = TextEditingController(text: isEdit ? recordToEdit.cost.toString() : '');
    final odoController = TextEditingController(text: isEdit ? recordToEdit.odoReading.toString() : vehicle.currentOdo.toString());

    DateTime selectedDate = isEdit ? recordToEdit.date : DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Service' : 'Add Service'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: typeController,
                      decoration: const InputDecoration(labelText: 'Service Type'),
                    ),
                    TextField(
                      controller: costController,
                      decoration: const InputDecoration(labelText: 'Cost (₹)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: odoController,
                      decoration: const InputDecoration(labelText: 'ODO Reading'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('MMM dd, yyyy').format(selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null && picked != selectedDate) {
                              setState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final db = ref.read(databaseProvider);

                    if (isEdit) {
                      // Update existing record
                      final updatedRecord = ServiceRecord(
                        id: recordToEdit.id, // KEEP THE SAME ID
                        vehicleId: vehicle.id!,
                        date: selectedDate,
                        serviceType: typeController.text,
                        cost: double.tryParse(costController.text) ?? 0.0,
                        odoReading: int.tryParse(odoController.text) ?? 0,
                      );
                      await db.updateServiceRecord(updatedRecord);
                    } else {
                      // Insert new record
                      final newRecord = ServiceRecord(
                        vehicleId: vehicle.id!,
                        date: selectedDate,
                        serviceType: typeController.text,
                        cost: double.tryParse(costController.text) ?? 0.0,
                        odoReading: int.tryParse(odoController.text) ?? 0,
                      );
                      await db.insertServiceRecord(newRecord);
                    }

                    ref.refresh(serviceRecordsProvider(vehicle.id!));
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}