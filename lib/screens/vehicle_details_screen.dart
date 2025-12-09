import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
import '../providers.dart';
import '../data/database.dart';
import '../data/models.dart';

// --- CONSTANTS ---
const List<String> kTrackedServices = [
  'Engine Oil', 'Brake Fluid', 'Air Filter', 'Spark Plug', 'Fuel Cleaner', 'Other' 
];

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
    final vehicle = widget.vehicle;
    final recordsAsync = ref.watch(serviceRecordsProvider(vehicle.id!));
    final allVehiclesAsync = ref.watch(vehicleListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, 
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search history...',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  border: InputBorder.none,
                  fillColor: Colors.transparent, 
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              )
            : null, 
        
        actions: [
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
              onPressed: () => setState(() => _isSearching = true),
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
          // --- CALCULATIONS ---
          int displayOdo = vehicle.currentOdo;
          if (records.isNotEmpty) {
            final maxHistory = records.map((r) => r.odoReading).reduce((a, b) => a > b ? a : b);
            if (maxHistory > displayOdo) displayOdo = maxHistory;
          }

          final currentYear = DateTime.now().year;
          final yearCost = records
              .where((r) => r.date.year == currentYear)
              .fold(0.0, (sum, r) => sum + r.cost);

          // --- FILTERING ---
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

              // Timeline List
              Expanded(
                child: filteredRecords.isEmpty 
                  ? (_searchQuery.isEmpty 
                      ? _buildEmptyLog(context) 
                      : Center(child: Text("No matching records found", style: TextStyle(color: Colors.grey))))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80), 
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

  // --- HEADER (Dark Mode Adaptive) ---
  Widget _buildHeader(BuildContext context, WidgetRef ref, int displayOdo, double yearCost, List<Vehicle> allVehicles) {
    final vehicle = widget.vehicle;
    final bool hasOffset = vehicle.odoOffset > 0;
    final int dashReading = (displayOdo > vehicle.odoOffset) ? (displayOdo - vehicle.odoOffset) : displayOdo;
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final decoration = isDark 
        ? BoxDecoration(
            color: theme.cardTheme.color, 
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          )
        : BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.85)],
              begin: Alignment.topLeft, 
              end: Alignment.bottomRight
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
          );

    final mainTextColor = isDark ? theme.colorScheme.onSurface : Colors.white;
    final subTextColor = isDark ? theme.colorScheme.onSurface.withOpacity(0.6) : Colors.white.withOpacity(0.8);
    final iconBgColor = isDark ? theme.colorScheme.primary.withOpacity(0.1) : Colors.white.withOpacity(0.15);
    final iconColor = isDark ? theme.colorScheme.primary : Colors.white;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: decoration,
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
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: vehicle.id,
                        icon: Icon(Icons.keyboard_arrow_down, color: subTextColor),
                        dropdownColor: theme.colorScheme.surface, 
                        isExpanded: true,
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold, 
                          color: mainTextColor, 
                          fontFamily: theme.textTheme.bodyLarge?.fontFamily
                        ),
                        selectedItemBuilder: (BuildContext context) {
                          return allVehicles.map<Widget>((Vehicle item) {
                            return Text(item.name, overflow: TextOverflow.ellipsis, style: TextStyle(color: mainTextColor));
                          }).toList();
                        },
                        items: allVehicles.map((v) {
                          return DropdownMenuItem<int>(
                            value: v.id, 
                            child: Text(v.name, style: TextStyle(color: theme.colorScheme.onSurface)),
                          );
                        }).toList(),
                        onChanged: (newId) {
                          if (newId != null && newId != vehicle.id) {
                            final newVehicle = allVehicles.firstWhere((v) => v.id == newId);
                            Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (context, anim1, anim2) => VehicleDetailsScreen(vehicle: newVehicle), transitionDuration: Duration.zero, reverseTransitionDuration: Duration.zero));
                          }
                        },
                      ),
                    ),
                    Text('${vehicle.make} ${vehicle.model}', style: TextStyle(color: subTextColor, fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)), 
                child: FaIcon(FontAwesomeIcons.car, size: 24, color: iconColor)
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: subTextColor.withOpacity(0.2), height: 1),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => _showUpdateOdoDialog(context, ref, currentOdo: displayOdo),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('CURRENT ODO', style: TextStyle(color: subTextColor, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600)), 
                        const SizedBox(width: 6), 
                        Icon(Icons.edit, size: 12, color: subTextColor)
                      ]),
                      const SizedBox(height: 4),
                      if (hasOffset) ...[
                        Text('$displayOdo km', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: mainTextColor)),
                        Text('Dash: $dashReading km', style: TextStyle(fontSize: 13, color: subTextColor)),
                      ] else 
                        Text('$displayOdo km', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: mainTextColor)),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('COST (${DateTime.now().year})', style: TextStyle(color: subTextColor, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('₹${yearCost.toStringAsFixed(0)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: mainTextColor)),
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
          FilledButton( 
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
                      enabled: !isEdit, 
                      decoration: InputDecoration(
                        labelText: 'Dashboard Reading', 
                        helperText: isEdit 
                            ? 'Cannot change ODO on edit' 
                            : (vehicle.odoOffset > 0 ? '+ ${vehicle.odoOffset} km offset' : null),
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
                FilledButton(
                  onPressed: () async {
                    int finalOdo;
                    if (isEdit) {
                        finalOdo = recordToEdit.odoReading; 
                    } else {
                        final int inputReading = int.tryParse(odoController.text) ?? 0;
                        finalOdo = inputReading + vehicle.odoOffset;
                        if (finalOdo < currentOdo) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New Total cannot be less than current!'), backgroundColor: Colors.red));
                           return;
                        }
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

                    if (!isEdit && finalOdo > currentOdo) {
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

  void _showDetailsDialog(BuildContext context, ServiceRecord record) {
    showDialog(context: context, builder: (context) { return AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Row(children: [CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.build, color: Theme.of(context).colorScheme.primary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(record.serviceType, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(DateFormat('MMMM dd, yyyy').format(record.date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]))]), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Divider(), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildDetailItem(context, Icons.currency_rupee, 'Cost', '₹${record.cost.toStringAsFixed(0)}'), _buildDetailItem(context, Icons.speed, 'ODO', '${record.odoReading} km')]), const SizedBox(height: 20), const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 5), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.2))), child: Text(record.notes.isEmpty ? 'No notes added.' : record.notes, style: TextStyle(color: record.notes.isEmpty ? Colors.grey : Theme.of(context).colorScheme.onSurface, fontStyle: record.notes.isEmpty ? FontStyle.italic : FontStyle.normal)))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]); });
  }

  Widget _buildDetailItem(BuildContext context, IconData icon, String label, String value) {
    return Row(children: [Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])]);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int recordId) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Delete Record?'), content: const Text('This cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () async { final db = ref.read(databaseProvider); await db.deleteServiceRecord(recordId); ref.refresh(allExpensesProvider); ref.refresh(serviceRecordsProvider(widget.vehicle.id!)); if (context.mounted) Navigator.pop(context); }, child: const Text('Delete', style: TextStyle(color: Colors.red)))]));
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final vehicle = widget.vehicle;
    try { FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']); if (result != null) { File file = File(result.files.single.path!); final input = file.openRead(); final fields = await input.transform(utf8.decoder).transform(const CsvToListConverter()).toList(); final db = ref.read(databaseProvider); int importCount = 0; for (var i = 1; i < fields.length; i++) { final row = fields[i]; if (row.length < 4) continue; String dateStr = row[0].toString().trim(); String type = row[1].toString().trim(); double cost = double.tryParse(row[2].toString()) ?? 0.0; int odo = int.tryParse(row[3].toString()) ?? 0; String notes = ''; if (row.length > 4) notes = row[4].toString().trim(); DateTime date = DateTime.now(); try { date = DateTime.parse(dateStr); } catch (_) {} final record = ServiceRecord(vehicleId: vehicle.id!, date: date, serviceType: type, cost: cost, odoReading: odo, notes: notes); await db.insertServiceRecord(record); importCount++; } if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $importCount records!'))); ref.refresh(serviceRecordsProvider(vehicle.id!)); ref.refresh(allExpensesProvider); ref.refresh(vehicleListProvider); } } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
  }

  Widget _buildEmptyLog(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [FaIcon(FontAwesomeIcons.clipboardList, size: 60, color: Colors.grey.shade300), SizedBox(height: 10), Text('No service history yet', style: TextStyle(color: Colors.grey))]));
  }
}

// --- DASHBOARD (Refined) ---
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
    String subValue = 'Tap + to add';
    bool hasData = false;

    if (relevantRecords.isNotEmpty) {
      hasData = true;
      relevantRecords.sort((a, b) => b.date.compareTo(a.date));
      final lastRecord = relevantRecords.first; 
      final distDriven = vehicleOdo - lastRecord.odoReading;
      mainValue = '${distDriven < 0 ? 0 : distDriven} km'; 
      final diff = DateTime.now().difference(lastRecord.date).inDays;
      if (diff < 30) subValue = '$diff days ago';
      else subValue = '${(diff / 30).toStringAsFixed(1)} mo. ago';
    }

    return Container(
      width: 140, 
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.wrench, size: 14, color: hasData ? Theme.of(context).colorScheme.secondary : Colors.grey.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(mainValue, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: hasData ? Theme.of(context).colorScheme.onSurface : Colors.grey.shade400)),
          const SizedBox(height: 2),
          Text(subValue, style: TextStyle(fontSize: 11, color: hasData ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6) : Colors.grey.shade400)),
        ],
      ),
    );
  }
}

// --- TIMELINE ITEM (Updated with Edit Menu) ---
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
          // Timeline Line
          Column(children: [
            Container(
              width: 14, height: 14, 
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface, 
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
              )
            ),
            if (!isLast) Expanded(child: Container(width: 2, color: Theme.of(context).dividerColor.withOpacity(0.5))),
          ]),
          const SizedBox(width: 16),
          
          // Card Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMM dd, yyyy').format(record.date), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), 
                      side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))
                    ),
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Title + Menu Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(record.serviceType, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                                
                                // 👇 ADDED MENU BUTTON HERE
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                                  onSelected: (val) { 
                                    if (val == 'edit') onEdit(); 
                                    if (val == 'delete') onDelete(); 
                                  }, 
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                                  ]
                                ),
                              ],
                            ),
                            
                            // Cost Row
                            Text(
                              '₹${record.cost.toStringAsFixed(0)}', 
                              style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 16)
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Bottom Row: ODO
                            Row(
                              children: [
                                Icon(Icons.speed, size: 14, color: Colors.grey.shade500), 
                                const SizedBox(width: 6), 
                                Text(odoText, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                if (showDash) ...[
                                  const SizedBox(width: 8),
                                  Text(dashText, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500, fontSize: 13)),
                                ],
                              ],
                            ),
                          ],
                        ),
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