class Vehicle {
  // Sembast generates int IDs automatically
  final int? id; 
  final String name;
  final String make;
  final String model;
  final int currentOdo;

  Vehicle({this.id, required this.name, required this.make, this.model = '', required this.currentOdo});

  // Convert to Map for saving
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'make': make,
      'model': model,
      'currentOdo': currentOdo,
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

  ServiceRecord({
    this.id,
    required this.vehicleId,
    required this.date,
    required this.odoReading,
    required this.serviceType,
    required this.cost,
  });

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'date': date.toIso8601String(),
      'odoReading': odoReading,
      'serviceType': serviceType,
      'cost': cost,
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
    );
  }
}