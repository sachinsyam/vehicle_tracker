import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; 
import '../providers.dart';
import '../data/models.dart';

class ExpenseReportScreen extends ConsumerStatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  ConsumerState<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends ConsumerState<ExpenseReportScreen> {
  int? _selectedVehicleId;
  DateTimeRange? _selectedDateRange;
  String _dateLabel = 'All Time';

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

              // Filter: Hide 0 cost entries (ODO updates)
              filteredRecords = filteredRecords.where((r) => r.cost > 0).toList();

              // Filter: Vehicle
              if (_selectedVehicleId != null) {
                filteredRecords = filteredRecords
                    .where((r) => r.vehicleId == _selectedVehicleId)
                    .toList();
              }

              // Filter: Date
              if (_selectedDateRange != null) {
                filteredRecords = filteredRecords.where((r) {
                  final recordDate = DateUtils.dateOnly(r.date);
                  final start = DateUtils.dateOnly(_selectedDateRange!.start);
                  final end = DateUtils.dateOnly(_selectedDateRange!.end);
                  return !recordDate.isBefore(start) && !recordDate.isAfter(end);
                }).toList();
              }

              final totalCost = filteredRecords.fold(0.0, (sum, item) => sum + item.cost);

              final vehicleNames = {
                for (var v in vehicles) v.id!: '${v.make} ${v.model}'
              };

              // --- 2. DATA PREP FOR GRAPH (Monthly Totals) ---
              // Aggregate costs by month (1-12)
              final Map<int, double> monthlyCosts = {}; 
              for (var record in filteredRecords) {
                final month = record.date.month;
                monthlyCosts[month] = (monthlyCosts[month] ?? 0) + record.cost;
              }

              // Build Chart Bars
              List<BarChartGroupData> barGroups = [];
              for (int i = 1; i <= 12; i++) {
                barGroups.add(
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: monthlyCosts[i] ?? 0,
                        color: Theme.of(context).colorScheme.primary,
                        width: 16, // Thicker bars
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: (monthlyCosts.values.isEmpty ? 0 : monthlyCosts.values.reduce((a, b) => a > b ? a : b)) * 1.1, // Dynamic max height
                          color: Colors.grey.shade100,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView( 
                child: Column(
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
                          Text(
                            '${_selectedVehicleId == null ? "All Vehicles" : vehicleNames[_selectedVehicleId]} • $_dateLabel',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),

                    // --- CHART SECTION ---
                    if (totalCost > 0) ...[
                      Container(
                        height: 220,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: (monthlyCosts.values.isEmpty ? 0 : monthlyCosts.values.reduce((a, b) => a > b ? a : b)) * 1.2, 
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    '${DateFormat('MMM').format(DateTime(0, group.x.toInt()))}\n',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    children: [
                                      TextSpan(
                                        text: '₹${rod.toY.toStringAsFixed(0)}',
                                        style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10);
                                    // Show Labels for alternate months to avoid clutter
                                    if (value % 2 != 0) { 
                                       return SideTitleWidget(axisSide: meta.axisSide, child: Text(DateFormat('MMM').format(DateTime(0, value.toInt())), style: style));
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: barGroups,
                          ),
                        ),
                      ),
                      const Divider(),
                    ],

                    // --- FILTER BAR ---
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          InputChip(
                            avatar: const Icon(Icons.directions_car, size: 18),
                            label: Text(_selectedVehicleId == null ? 'All Vehicles' : vehicleNames[_selectedVehicleId] ?? 'Vehicle'),
                            onPressed: () => _showVehicleFilterDialog(context, vehicles),
                            deleteIcon: _selectedVehicleId != null ? const Icon(Icons.close, size: 16) : null,
                            onDeleted: _selectedVehicleId != null ? () => setState(() => _selectedVehicleId = null) : null,
                          ),
                          const SizedBox(width: 10),
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
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                            child: const Icon(Icons.receipt_long, size: 20, color: Colors.black54),
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
                    const SizedBox(height: 40),
                  ],
                ),
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
            // NEW: This Month
            ListTile(
              leading: const Icon(Icons.calendar_view_month),
              title: const Text('This Month'),
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _selectedDateRange = DateTimeRange(
                    start: DateTime(now.year, now.month, 1),
                    end: DateTime(now.year, now.month + 1, 0),
                  );
                  _dateLabel = 'This Month';
                });
                Navigator.pop(context);
              },
            ),
            // NEW: This Year
            ListTile(
              leading: const Icon(Icons.calendar_today),
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
                Navigator.pop(context);
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