import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../data/models.dart';

// We change to ConsumerStatefulWidget to hold the filter state
class ExpenseReportScreen extends ConsumerStatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  ConsumerState<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends ConsumerState<ExpenseReportScreen> {
  // --- STATE VARIABLES ---
  int? _selectedVehicleId; // null = All Vehicles
  DateTimeRange? _selectedDateRange; // null = All Time
  String _dateLabel = 'All Time'; // Text to show on the button

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(allExpensesProvider);
    final vehiclesAsync = ref.watch(vehicleListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Expense Report')),
      body: expensesAsync.when(
        data: (allRecords) {
          return vehiclesAsync.when(
            data: (vehicles) {
              // --- 1. FILTER LOGIC ---
              var filteredRecords = allRecords;

              // Filter by Vehicle
              if (_selectedVehicleId != null) {
                filteredRecords = filteredRecords
                    .where((r) => r.vehicleId == _selectedVehicleId)
                    .toList();
              }

              // Filter by Date
              if (_selectedDateRange != null) {
                filteredRecords = filteredRecords.where((r) {
                  // Normalize dates to ignore time parts for accurate comparison
                  final recordDate = DateUtils.dateOnly(r.date);
                  final start = DateUtils.dateOnly(_selectedDateRange!.start);
                  final end = DateUtils.dateOnly(_selectedDateRange!.end);
                  return !recordDate.isBefore(start) && !recordDate.isAfter(end);
                }).toList();
              }

              // Calculate Total of FILTERED list
              final totalCost = filteredRecords.fold(0.0, (sum, item) => sum + item.cost);

              // Vehicle Name Lookup Map
              final vehicleNames = {
                for (var v in vehicles) v.id!: '${v.make} ${v.model}'
              };

              return Column(
                children: [
                  // --- SUMMARY CARD ---
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text('Total Expenses', style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer)),
                        const SizedBox(height: 5),
                        Text(
                          '₹${totalCost.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSecondaryContainer),
                        ),
                        const SizedBox(height: 5),
                        // Show active filters in the summary card
                        Text(
                          '${_selectedVehicleId == null ? "All Vehicles" : vehicleNames[_selectedVehicleId]} • $_dateLabel',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),

                  // --- FILTER BAR ---
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Vehicle Dropdown Chip
                        InputChip(
                          avatar: const Icon(Icons.directions_car, size: 18),
                          label: Text(_selectedVehicleId == null ? 'All Vehicles' : vehicleNames[_selectedVehicleId] ?? 'Vehicle'),
                          onPressed: () => _showVehicleFilterDialog(context, vehicles),
                          deleteIcon: _selectedVehicleId != null ? const Icon(Icons.close, size: 16) : null,
                          onDeleted: _selectedVehicleId != null ? () => setState(() => _selectedVehicleId = null) : null,
                        ),
                        const SizedBox(width: 10),
                        // Date Dropdown Chip
                        InputChip(
                          avatar: const Icon(Icons.calendar_today, size: 18),
                          label: Text(_dateLabel),
                          onPressed: () => _showDateFilterDialog(context),
                          deleteIcon: _selectedDateRange != null ? const Icon(Icons.close, size: 16) : null,
                          onDeleted: _selectedDateRange != null ? () {
                            setState(() {
                              _selectedDateRange = null;
                              _dateLabel = 'All Time';
                            });
                          } : null,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),

                  // --- LIST OF EXPENSES ---
                  Expanded(
                    child: filteredRecords.isEmpty
                        ? const Center(child: Text('No records match your filters.'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredRecords.length,
                            separatorBuilder: (c, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final record = filteredRecords[index];
                              final vehicleName = vehicleNames[record.vehicleId] ?? 'Unknown';

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey.shade200,
                                  child: const Icon(Icons.attach_money, size: 20, color: Colors.black54),
                                ),
                                title: Text(record.serviceType, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${DateFormat('MMM dd, yyyy').format(record.date)} • $vehicleName'),
                                trailing: Text(
                                  '₹${record.cost.toStringAsFixed(0)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.secondary),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  // --- FILTER 1: VEHICLE DIALOG ---
  void _showVehicleFilterDialog(BuildContext context, List<Vehicle> vehicles) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.garage),
              title: const Text('All Vehicles'),
              selected: _selectedVehicleId == null,
              onTap: () {
                setState(() => _selectedVehicleId = null);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ...vehicles.map((v) => ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: Text('${v.make} ${v.model}'),
                  selected: _selectedVehicleId == v.id,
                  onTap: () {
                    setState(() => _selectedVehicleId = v.id);
                    Navigator.pop(context);
                  },
                )),
          ],
        );
      },
    );
  }

  // --- FILTER 2: DATE DIALOG ---
  void _showDateFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('All Time'),
              onTap: () {
                setState(() {
                  _selectedDateRange = null;
                  _dateLabel = 'All Time';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('This Year'),
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _selectedDateRange = DateTimeRange(
                    start: DateTime(now.year, 1, 1),
                    end: DateTime(now.year, 12, 31),
                  );
                  _dateLabel = 'This Year';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Custom Range...'),
              onTap: () async {
                Navigator.pop(context); // Close sheet first
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  initialDateRange: _selectedDateRange,
                );
                if (picked != null) {
                  setState(() {
                    _selectedDateRange = picked;
                    _dateLabel = '${DateFormat('MMM d').format(picked.start)} - ${DateFormat('MMM d').format(picked.end)}';
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }
}