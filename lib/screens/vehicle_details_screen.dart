import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../data/database.dart';
import '../data/models.dart';

// --- CONSTANTS ---
const List<String> kTrackedServices = [
  'Engine Oil',
  'Brake Fluid',
  'Air Filter',
  'Spark Plug',
  'Fuel Cleaner',
  'Other' 
];

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
      ),
      body: Column(
        children: [
          // 1. The Header (Blue Gradient)
          _buildHeader(context),

          // 2. The Compact Maintenance Dashboard (Horizontal Scroll)
          recordsAsync.when(
            data: (records) => _MaintenanceDashboard(
              vehicleOdo: vehicle.currentOdo,
              records: records,
            ),
            loading: () => const SizedBox(), 
            error: (_, __) => const SizedBox(),
          ),

          const SizedBox(height: 10),

          // 3. The Timeline List (UNCHANGED)
          Expanded(
            child: recordsAsync.when(
              data: (records) {
                if (records.isEmpty) return _buildEmptyLog();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${vehicle.currentOdo} km',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '${vehicle.make} ${vehicle.model}',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
              ),
            ],
          ),
          const Icon(Icons.two_wheeler, size: 32, color: Colors.white),
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

  void _showServiceDialog(BuildContext context, WidgetRef ref, {ServiceRecord? recordToEdit}) {
    final isEdit = recordToEdit != null;
    
    String initialType = kTrackedServices[0];
    if (isEdit) {
      if (kTrackedServices.contains(recordToEdit.serviceType)) {
        initialType = recordToEdit.serviceType;
      } else {
        initialType = 'Other';
      }
    }

    final customTypeController = TextEditingController(text: isEdit ? recordToEdit.serviceType : '');
    final costController = TextEditingController(text: isEdit ? recordToEdit.cost.toString() : '');
    final odoController = TextEditingController(text: isEdit ? recordToEdit.odoReading.toString() : vehicle.currentOdo.toString());
    
    DateTime selectedDate = isEdit ? recordToEdit.date : DateTime.now();
    String selectedDropdown = initialType;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isOther = selectedDropdown == 'Other';
            return AlertDialog(
              title: Text(isEdit ? 'Edit Service' : 'Add Service'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedDropdown,
                      decoration: const InputDecoration(labelText: 'Service Type'),
                      items: kTrackedServices.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedDropdown = newValue!;
                        });
                      },
                    ),
                    if (isOther)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextField(
                          controller: customTypeController,
                          decoration: const InputDecoration(labelText: 'Custom Service Name'),
                        ),
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
                        Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
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
                              setState(() => selectedDate = picked);
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
    // 1. Get Inputs
    String finalType = selectedDropdown;
    if (selectedDropdown == 'Other') {
      finalType = customTypeController.text.trim();
      if (finalType.isEmpty) finalType = 'General Service';
    }

    final double cost = double.tryParse(costController.text) ?? 0.0;
    final int newOdo = int.tryParse(odoController.text) ?? 0;

    final db = ref.read(databaseProvider);
    
    // 2. Save Service Record
    final record = ServiceRecord(
      id: isEdit ? recordToEdit.id : null,
      vehicleId: vehicle.id!,
      date: selectedDate,
      serviceType: finalType,
      cost: cost,
      odoReading: newOdo,
    );

    if (isEdit) {
      await db.updateServiceRecord(record);
    } else {
      await db.insertServiceRecord(record);
    }

    // 3. AUTO-UPDATE VEHICLE ODO (The Logic You Wanted)
    if (newOdo > vehicle.currentOdo) {
      final updatedVehicle = Vehicle(
        id: vehicle.id, // IMPORTANT: Use the SAME ID
        name: vehicle.name,
        make: vehicle.make,
        model: vehicle.model,
        currentOdo: newOdo, // Update to the new higher ODO
      );
      
      // Update the DB entry so it persists permanently
      await db.updateVehicle(updatedVehicle);
      
      // Refresh the Home Screen list so it shows the new ODO there too
      ref.refresh(vehicleListProvider);
    }

    // 4. Refresh List & Close
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

// --- SIMPLIFIED DASHBOARD (Shows Last Service ODO) ---
class _MaintenanceDashboard extends StatelessWidget {
  final int vehicleOdo;
  final List<ServiceRecord> records;

  const _MaintenanceDashboard({required this.vehicleOdo, required this.records});

  @override
  Widget build(BuildContext context) {
    // Only show tracked items (exclude 'Other')
    final trackedItems = kTrackedServices.where((e) => e != 'Other').toList();

    return Container(
      height: 105,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: trackedItems.length,
        separatorBuilder: (c, i) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _buildStatusCard(context, trackedItems[index]);
        },
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, String type) {
    final relevantRecords = records.where((r) => r.serviceType == type).toList();
    
    String mainValue = '---'; // Default if empty
    String subValue = 'Tap to add';
    bool hasData = false;

    if (relevantRecords.isNotEmpty) {
      hasData = true;
      // Sort by date to find the latest
      relevantRecords.sort((a, b) => b.date.compareTo(a.date));
      final lastRecord = relevantRecords.first;
      
      // --- LOGIC: Just show the ODO reading of the record ---
      mainValue = '${lastRecord.odoReading} km';
      
      // --- LOGIC: Show the Date ---
      subValue = DateFormat('MMM dd, yyyy').format(lastRecord.date);
    }

    return Container(
      width: 140, 
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.build_circle, size: 16, color: hasData ? Theme.of(context).colorScheme.primary : Colors.grey.shade300),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 12, 
                    color: Colors.grey.shade600, 
                    fontWeight: FontWeight.bold
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // The ODO Reading (Big Bold Text)
          Text(
            mainValue,
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: hasData ? Colors.black87 : Colors.grey.shade300
            ),
          ),
          
          // The Date (Small Grey Text)
          Text(
            subValue, 
            style: const TextStyle(fontSize: 11, color: Colors.blueGrey)
          ),
        ],
      ),
    );
  }
}
// --- TIMELINE ITEM (The visual style you liked) ---
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(record.date),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
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