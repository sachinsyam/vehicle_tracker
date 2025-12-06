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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(vehicle.name),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined))
        ],
      ),
      body: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 10),
          Expanded(
            child: recordsAsync.when(
              data: (records) {
                if (records.isEmpty) return _buildEmptyLog();
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final isLast = index == records.length - 1;
                    return _TimelineItem(
                      record: records[index],
                      isLast: isLast,
                      ref: ref,
                      onEdit: () => _showServiceDialog(context, ref, recordToEdit: records[index]),
                      onDelete: () => _confirmDelete(context, ref, records[index].id!),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.two_wheeler, size: 40, color: Colors.white),
          const SizedBox(height: 10),
          Text(
            '${vehicle.currentOdo} km',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            '${vehicle.make} ${vehicle.model}',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLog() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 60, color: Colors.grey),
          SizedBox(height: 10),
          Text('No service history recorded.'),
        ],
      ),
    );
  }

  // --- KEEP YOUR EXISTING DIALOG FUNCTIONS ---
  // Paste _confirmDelete and _showServiceDialog from the previous step here.
  // I am omitting them to save space, but they are exactly the same as before.
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

// --- VISUAL COMPONENT: TIMELINE ITEM ---
class _TimelineItem extends StatelessWidget {
  final ServiceRecord record;
  final bool isLast;
  final WidgetRef ref;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TimelineItem({
    required this.record, 
    required this.isLast, 
    required this.ref,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. The Timeline Line
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          
          // 2. The Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date
                  Text(
                    DateFormat('MMM dd, yyyy').format(record.date),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        record.serviceType,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(Icons.speed, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text('${record.odoReading} km'),
                            const SizedBox(width: 16),
                            Icon(Icons.currency_rupee, size: 14, color: Theme.of(context).colorScheme.secondary),
                            Text(
                              record.cost.toStringAsFixed(0),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (val) {
                          if (val == 'edit') onEdit();
                          if (val == 'delete') onDelete();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}