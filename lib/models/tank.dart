class Tank {
  final String id;
  final String fuelType;
  final double capacity;
  double currentLevel;

  Tank({
    required this.id,
    required this.fuelType,
    required this.capacity,
    required this.currentLevel,
  });

  double get percentageFilled => (currentLevel / capacity) * 100;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fuelType': fuelType,
      'capacity': capacity,
      'currentLevel': currentLevel,
    };
  }

  factory Tank.fromMap(Map<String, dynamic> map) {
    return Tank(
      id: map['id'],
      fuelType: map['fuelType'],
      capacity: map['capacity'],
      currentLevel: map['currentLevel'],
    );
  }
  Tank copyWith({
    String? id,
    String? fuelType,
    double? capacity,
    double? currentLevel,
  }) {
    return Tank(
      id: id ?? this.id,
      fuelType: fuelType ?? this.fuelType,
      capacity: capacity ?? this.capacity,
      currentLevel: currentLevel ?? this.currentLevel,
    );
  }
}
