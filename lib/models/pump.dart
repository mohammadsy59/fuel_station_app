class Pump {
  final String id;
  final String connectedTankId;
  double digitalCounter;
  double mechanicalCounter;

  Pump({
    required this.id,
    required this.connectedTankId,
    required this.digitalCounter,
    required this.mechanicalCounter,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'connectedTankId': connectedTankId,
      'digitalCounter': digitalCounter,
      'mechanicalCounter': mechanicalCounter,
    };
  }

  factory Pump.fromMap(Map<String, dynamic> map) {
    return Pump(
      id: map['id'],
      connectedTankId: map['connectedTankId'],
      digitalCounter: map['digitalCounter'],
      mechanicalCounter: map['mechanicalCounter'],
    );
  }
  Pump copyWith({
    String? id,
    String? connectedTankId,
    double? digitalCounter,
    double? mechanicalCounter,
  }) {
    return Pump(
      id: id ?? this.id,
      connectedTankId: connectedTankId ?? this.connectedTankId,
      digitalCounter: digitalCounter ?? this.digitalCounter,
      mechanicalCounter: mechanicalCounter ?? this.mechanicalCounter,
    );
  }
}
