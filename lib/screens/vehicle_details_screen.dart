import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../data/database.dart';
import '../data/models.dart';

// --- CONSTANTS ---
const List<String> kTrackedServices = [
  'Engine Oil', 'Brake Fluid', 'Air Filter', 'Spark Plug', 'Fuel Cleaner', 'Other' 
];

// 👇 Changed to ConsumerStatefulWidget to handle Search State
class VehicleDetailsScreen extends ConsumerStatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailsScreen({super.key, required this.vehicle});

  @override
  ConsumerState<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends ConsumerState<VehicleDetailsScreen> {
  // --- SEARCH STATE ---
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle; // Access vehicle from widget
    final recordsAsync = ref.watch(serviceRecordsProvider(vehicle.id!));
    final allVehiclesAsync = ref.watch(vehicleListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        // 👇 Dynamic Title: Show TextField if searching
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                decoration: const InputDecoration(
                  hintText: 'Search notes, service type...',
                  hintStyle: TextStyle(color: Color.fromARGB(179, 114, 107, 107)),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              )
            : null, // Default empty title to let Header handle context
        
        actions: [
          // 👇 Search Toggle Logic
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Import CSV',
              onPressed: () => _importCsv(context, ref),
            ),
          ]
        ],
      ),
      body: recordsAsync.when(
        data: (records) {
          // --- CALCULATIONS (Using ALL records) ---
          int displayOdo = vehicle.currentOdo;
          if (records.isNotEmpty) {
            final maxHistory = records.map((r) => r.odoReading).reduce((a, b) => a > b ? a : b);
            if (maxHistory > displayOdo) displayOdo = maxHistory;
          }

          final currentYear = DateTime.now().year;
          final yearCost = records
              .where((r) => r.date.year == currentYear)
              .fold(0.0, (sum, r) => sum + r.cost);

          // --- FILTERING LOGIC ---
          final filteredRecords = records.where((r) {
            if (_searchQuery.isEmpty) return true;
            return r.serviceType.toLowerCase().contains(_searchQuery) ||
                   r.notes.toLowerCase().contains(_searchQuery) ||
                   r.cost.toString().contains(_searchQuery);
          }).toList();

          return Column(
            children: [
              // Header
              allVehiclesAsync.when(
                data: (allVehicles) => _buildHeader(context, ref, displayOdo, yearCost, allVehicles),
                loading: () => const SizedBox(height: 100), 
                error: (_, __) => const SizedBox(),
              ),

              // Dashboard
              _MaintenanceDashboard(vehicleOdo: displayOdo, records: records),

              const SizedBox(height: 10),

              // Timeline List (Uses FILTERED records)
              Expanded(
                child: filteredRecords.isEmpty 
                  ? (_searchQuery.isEmpty 
                      ? _buildEmptyLog() 
                      : const Center(child: Text("No records found", style: TextStyle(color: Colors.grey))))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        return _TimelineItem(
                          record: filteredRecords[index],
                          isLast: index == filteredRecords.length - 1,
                          vehicleOffset: vehicle.odoOffset,
                          ref: ref,
                          onTap: () => _showDetailsDialog(context, filteredRecords[index]),
                          onEdit: () => _showServiceDialog(context, ref, recordToEdit: filteredRecords[index], currentOdo: displayOdo),
                          onDelete: () => _confirmDelete(context, ref, filteredRecords[index].id!),
                        );
                      },
                    ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: recordsAsync.when(
        data: (records) {
          int displayOdo = vehicle.currentOdo;
          if (records.isNotEmpty) {
            final maxHistory = records.map((r) => r.odoReading).reduce((a, b) => a > b ? a : b);
            if (maxHistory > displayOdo) displayOdo = maxHistory;
          }
          // Hide FAB when searching to avoid clutter
          if (_isSearching) return null;
          
          return FloatingActionButton.extended(
            onPressed: () => _showServiceDialog(context, ref, currentOdo: displayOdo),
            label: const Text('Add Service'),
            icon: const Icon(Icons.add),
          );
        },
        loading: () => const SizedBox(),
        error: (_, __) => const SizedBox(),
      ),
    );
  }

  // --- HEADER ---
  Widget _buildHeader(BuildContext context, WidgetRef ref, int displayOdo, double yearCost, List<Vehicle> allVehicles) {
    final vehicle = widget.vehicle;
    final bool hasOffset = vehicle.odoOffset > 0;
    final int dashReading = (displayOdo > vehicle.odoOffset) ? (displayOdo - vehicle.odoOffset) : displayOdo;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButton<int>(
                      value: vehicle.id,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      dropdownColor: Theme.of(context).colorScheme.primary,
                      underline: const SizedBox(),
                      isExpanded: true,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Roboto'),
                      items: allVehicles.map((v) {
                        return DropdownMenuItem<int>(value: v.id, child: Text(v.name, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null && newId != vehicle.id) {
                          final newVehicle = allVehicles.firstWhere((v) => v.id == newId);
                          Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (context, anim1, anim2) => VehicleDetailsScreen(vehicle: newVehicle), transitionDuration: Duration.zero, reverseTransitionDuration: Duration.zero));
                        }
                      },
                    ),
                    Text('${vehicle.make} ${vehicle.model}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                  ],
                ),
              ),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.directions_car, size: 28, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => _showUpdateOdoDialog(context, ref, currentOdo: displayOdo),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Text('CURRENT ODO', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1)), const SizedBox(width: 4), Icon(Icons.edit, size: 12, color: Colors.white.withOpacity(0.5))]),
                    const SizedBox(height: 2),
                    if (hasOffset) ...[
                      Text('$displayOdo km', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Dash: $dashReading km', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8), fontStyle: FontStyle.italic)),
                    ] else 
                      Text('$displayOdo km', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('COST (${DateTime.now().year})', style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text('₹${yearCost.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  // --- MANUAL ODO UPDATE ---
  void _showUpdateOdoDialog(BuildContext context, WidgetRef ref, {required int currentOdo}) {
    final vehicle = widget.vehicle;
    int initialValue = currentOdo;
    if (vehicle.odoOffset > 0 && currentOdo > vehicle.odoOffset) {
      initialValue = currentOdo - vehicle.odoOffset;
    }
    
    final odoController = TextEditingController(text: initialValue.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update ODO'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the reading on your dashboard.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: odoController, 
              keyboardType: TextInputType.number, 
              decoration: InputDecoration(
                labelText: 'Dashboard Reading', 
                suffixText: 'km',
                helperText: vehicle.odoOffset > 0 ? '+ ${vehicle.odoOffset} km offset' : null,
              )
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
             onPressed: () async {
              final int inputReading = int.tryParse(odoController.text) ?? 0;
              final int finalOdo = inputReading + vehicle.odoOffset;

              if (finalOdo < currentOdo) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New Total cannot be lower than Current Total!'), backgroundColor: Colors.red));
                return;
              }
              
              final db = ref.read(databaseProvider);
              final record = ServiceRecord(vehicleId: vehicle.id!, date: DateTime.now(), serviceType: 'ODO Update', cost: 0, odoReading: finalOdo, notes: 'Manual update (Reading: $inputReading)');
              await db.insertServiceRecord(record);
              
              final updatedVehicle = Vehicle(id: vehicle.id, name: vehicle.name, make: vehicle.make, model: vehicle.model, currentOdo: finalOdo, odoOffset: vehicle.odoOffset);
              await db.updateVehicle(updatedVehicle);
              
              ref.refresh(vehicleListProvider);
              ref.refresh(serviceRecordsProvider(vehicle.id!));
              ref.refresh(allExpensesProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // --- SERVICE DIALOG ---
  void _showServiceDialog(BuildContext context, WidgetRef ref, {ServiceRecord? recordToEdit, required int currentOdo}) {
    final vehicle = widget.vehicle;
    final isEdit = recordToEdit != null;
    String initialType = kTrackedServices[0];
    if (isEdit) {
      if (kTrackedServices.contains(recordToEdit.serviceType)) initialType = recordToEdit.serviceType;
      else initialType = 'Other';
    }

    String initialOdoText = '';
    if (isEdit) {
      int raw = recordToEdit.odoReading;
      if (vehicle.odoOffset > 0 && raw > vehicle.odoOffset) raw -= vehicle.odoOffset;
      initialOdoText = raw.toString();
    } else {
      int raw = currentOdo;
      if (vehicle.odoOffset > 0 && raw > vehicle.odoOffset) raw -= vehicle.odoOffset;
      initialOdoText = raw.toString();
    }

    final customTypeController = TextEditingController(text: isEdit ? recordToEdit.serviceType : '');
    final costController = TextEditingController(text: isEdit ? recordToEdit.cost.toString() : '');
    final odoController = TextEditingController(text: initialOdoText);
    final notesController = TextEditingController(text: isEdit ? recordToEdit.notes : '');
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
                      items: kTrackedServices.map((String type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (val) => setState(() => selectedDropdown = val!),
                    ),
                    if (isOther) TextField(controller: customTypeController, decoration: const InputDecoration(labelText: 'Custom Name')),
                    TextField(controller: costController, decoration: const InputDecoration(labelText: 'Cost (₹)'), keyboardType: TextInputType.number),
                    TextField(
                      controller: odoController, 
                      decoration: InputDecoration(
                        labelText: 'Dashboard Reading', 
                        helperText: vehicle.odoOffset > 0 ? '+ ${vehicle.odoOffset} km offset' : null
                      ), 
                      keyboardType: TextInputType.number
                    ),
                    TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Notes (Optional)'), maxLines: 2),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                        const Spacer(),
                        TextButton(onPressed: () async { final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now()); if (picked != null) setState(() => selectedDate = picked); }, child: const Text('Change'))
                      ],
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final int inputReading = int.tryParse(odoController.text) ?? 0;
                    final int finalOdo = inputReading + vehicle.odoOffset;

                    if (!isEdit && finalOdo < currentOdo) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New Total cannot be less than current!'), backgroundColor: Colors.red));
                       return;
                    }

                    String finalType = selectedDropdown == 'Other' ? customTypeController.text.trim() : selectedDropdown;
                    if (finalType.isEmpty) finalType = 'General Service';
                    final db = ref.read(databaseProvider);
                    final record = ServiceRecord(
                      id: isEdit ? recordToEdit.id : null, 
                      vehicleId: vehicle.id!, 
                      date: selectedDate, 
                      serviceType: finalType, 
                      cost: double.tryParse(costController.text) ?? 0.0, 
                      odoReading: finalOdo, 
                      notes: notesController.text.trim()
                    );

                    if (isEdit) await db.updateServiceRecord(record);
                    else await db.insertServiceRecord(record);

                    if (finalOdo > currentOdo) {
                      final updatedVehicle = Vehicle(id: vehicle.id, name: vehicle.name, make: vehicle.make, model: vehicle.model, currentOdo: finalOdo, odoOffset: vehicle.odoOffset);
                      await db.updateVehicle(updatedVehicle);
                      ref.refresh(vehicleListProvider);
                    }
                    ref.refresh(allExpensesProvider);
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

  // --- DETAILS ---
  void _showDetailsDialog(BuildContext context, ServiceRecord record) {
    showDialog(context: context, builder: (context) { return AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Row(children: [CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.build, color: Theme.of(context).colorScheme.primary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(record.serviceType, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(DateFormat('MMMM dd, yyyy').format(record.date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]))]), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Divider(), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildDetailItem(context, Icons.currency_rupee, 'Cost', '₹${record.cost.toStringAsFixed(0)}'), _buildDetailItem(context, Icons.speed, 'ODO', '${record.odoReading} km')]), const SizedBox(height: 20), const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 5), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: Text(record.notes.isEmpty ? 'No notes added.' : record.notes, style: TextStyle(color: record.notes.isEmpty ? Colors.grey : Colors.black87, fontStyle: record.notes.isEmpty ? FontStyle.italic : FontStyle.normal)))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]); });
  }

  Widget _buildDetailItem(BuildContext context, IconData icon, String label, String value) {
    return Row(children: [Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])]);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int recordId) {
    final vehicle = widget.vehicle;
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Delete Record?'), content: const Text('This cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () async { final db = ref.read(databaseProvider); await db.deleteServiceRecord(recordId); ref.refresh(allExpensesProvider); ref.refresh(serviceRecordsProvider(vehicle.id!)); if (context.mounted) Navigator.pop(context); }, child: const Text('Delete', style: TextStyle(color: Colors.red)))]));
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final vehicle = widget.vehicle;
    try { FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']); if (result != null) { File file = File(result.files.single.path!); final input = file.openRead(); final fields = await input.transform(utf8.decoder).transform(const CsvToListConverter()).toList(); final db = ref.read(databaseProvider); int importCount = 0; for (var i = 1; i < fields.length; i++) { final row = fields[i]; if (row.length < 4) continue; String dateStr = row[0].toString().trim(); String type = row[1].toString().trim(); double cost = double.tryParse(row[2].toString()) ?? 0.0; int odo = int.tryParse(row[3].toString()) ?? 0; String notes = ''; if (row.length > 4) notes = row[4].toString().trim(); DateTime date = DateTime.now(); try { date = DateTime.parse(dateStr); } catch (_) {} final record = ServiceRecord(vehicleId: vehicle.id!, date: date, serviceType: type, cost: cost, odoReading: odo, notes: notes); await db.insertServiceRecord(record); importCount++; } if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $importCount records!'))); ref.refresh(serviceRecordsProvider(vehicle.id!)); ref.refresh(allExpensesProvider); ref.refresh(vehicleListProvider); } } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
  }

  Widget _buildEmptyLog() {
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history, size: 60, color: Colors.grey), SizedBox(height: 10), Text('No service history recorded.')]));
  }
}

// --- DASHBOARD ---
class _MaintenanceDashboard extends StatelessWidget {
  final int vehicleOdo;
  final List<ServiceRecord> records;

  const _MaintenanceDashboard({required this.vehicleOdo, required this.records});

  @override
  Widget build(BuildContext context) {
    final trackedItems = kTrackedServices.where((e) => e != 'Other').toList();
    return Container(
      height: 120, 
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: trackedItems.length,
        separatorBuilder: (c, i) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildStatusCard(context, trackedItems[index]),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, String type) {
    final relevantRecords = records.where((r) => r.serviceType == type).toList();
    
    String mainValue = '---'; 
    String subValue = 'Tap to add';
    bool hasData = false;

    if (relevantRecords.isNotEmpty) {
      hasData = true;
      relevantRecords.sort((a, b) => b.date.compareTo(a.date));
      final lastRecord = relevantRecords.first; 
      
      final distDriven = vehicleOdo - lastRecord.odoReading;
      final safeDist = distDriven < 0 ? 0 : distDriven;
      
      mainValue = '$safeDist km'; 
      
      final diff = DateTime.now().difference(lastRecord.date).inDays;
      if (diff < 30) {
        subValue = '$diff days ago';
      } else {
        final months = (diff / 30).toStringAsFixed(1);
        subValue = '$months mo. ago';
      }
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
          Row(
            children: [
              Icon(Icons.build_circle, size: 16, color: hasData ? Theme.of(context).colorScheme.primary : Colors.grey.shade300),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  type,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(mainValue, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: hasData ? Colors.black87 : Colors.grey.shade300)),
          Text(subValue, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
        ],
      ),
    );
  }
}

// --- TIMELINE ITEM ---
class _TimelineItem extends StatelessWidget {
  final ServiceRecord record;
  final bool isLast;
  final int vehicleOffset; 
  final WidgetRef ref;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TimelineItem({
    required this.record, 
    required this.isLast, 
    required this.vehicleOffset,
    required this.ref, 
    required this.onTap, 
    required this.onEdit, 
    required this.onDelete
  });

  @override
  Widget build(BuildContext context) {
    String odoText = '${record.odoReading} km';
    bool showDash = false;
    String dashText = '';

    if (vehicleOffset > 0 && record.odoReading > vehicleOffset) {
      showDash = true;
      dashText = '(Dash: ${record.odoReading - vehicleOffset} km)';
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary, shape: BoxShape.circle)),
            if (!isLast) Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
          ]),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMM dd, yyyy').format(record.date), style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0, 2))]),
                    child: ListTile(
                      onTap: onTap,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(record.serviceType, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(Icons.speed, size: 14, color: Colors.grey.shade600), 
                            const SizedBox(width: 4), 
                            Text(odoText, style: const TextStyle(fontWeight: FontWeight.w500)),
                            
                            if (showDash) ...[
                              const SizedBox(width: 8),
                              Text(
                                dashText, 
                                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)
                              ),
                            ],

                            const SizedBox(width: 16), 
                            Icon(Icons.currency_rupee, size: 14, color: Theme.of(context).colorScheme.secondary), 
                            Text(record.cost.toStringAsFixed(0), style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold))
                          ],
                        ),
                      ),
                      trailing: PopupMenuButton<String>(icon: const Icon(Icons.more_vert, size: 20), onSelected: (val) { if (val == 'edit') onEdit(); if (val == 'delete') onDelete(); }, itemBuilder: (context) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Delete'))]),
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