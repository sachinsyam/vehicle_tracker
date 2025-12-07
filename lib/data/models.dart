class Vehicle {
  // Sembast generates int IDs automatically
  final int? id; 
  final String name;
  final String make;
  final String model;
  final int currentOdo;
  final int odoOffset; // 👈 NEW FIELD: Stores the 'hidden' mileage

  Vehicle({
    this.id, 
    required this.name, 
    required this.make, 
    this.model = '', 
    required this.currentOdo,
    this.odoOffset = 0, // 👈 Default to 0 so it doesn't break existing data
  });

  // Convert to Map for saving
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'make': make,
      'model': model,
      'currentOdo': currentOdo,
      'odoOffset': odoOffset, // 👈 Save it
    };
  }

  // Create from Map (loading from DB)
  static Vehicle fromMap(int id, Map<String, dynamic> map) {
    return Vehicle(
      id: id,
      name: map['name'] as String,
      make: map['make'] as String,
      model: map['model'] as String,
      currentOdo: map['currentOdo'] as int,
      odoOffset: (map['odoOffset'] as int?) ?? 0, // 👈 Load it (safe null check)
    );
  }
}

class ServiceRecord {
  final int? id;
  final int vehicleId; // Links to Vehicle
  final DateTime date;
  final int odoReading;
  final String serviceType;
  final double cost;
  final String notes;

  ServiceRecord({
    this.id,
    required this.vehicleId,
    required this.date,
    required this.odoReading,
    required this.serviceType,
    required this.cost,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'date': date.toIso8601String(),
      'odoReading': odoReading,
      'serviceType': serviceType,
      'cost': cost,
      'notes': notes,
    };
  }

  static ServiceRecord fromMap(int id, Map<String, dynamic> map) {
    return ServiceRecord(
      id: id,
      vehicleId: map['vehicleId'] as int,
      date: DateTime.parse(map['date']),
      odoReading: map['odoReading'] as int,
      serviceType: map['serviceType'] as String,
      cost: (map['cost'] as num).toDouble(),
      notes: map['notes'] as String? ?? '',
    );
  }
}