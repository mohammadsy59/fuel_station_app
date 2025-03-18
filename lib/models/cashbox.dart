class Cashbox {
  final int? id; // Include ID
  final double usd;
  final double syp;
  final double tryCurrency;

  Cashbox({
    this.id, // Make ID optional
    required this.usd,
    required this.syp,
    required this.tryCurrency,
  });

  factory Cashbox.fromMap(Map<String, dynamic> map) {
    return Cashbox(
      id: map['id'], // Parse ID from the database
      usd: map['usd'],
      syp: map['syp'],
      tryCurrency: map['tryCurrency'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id ?? 1, // Default to ID 1 if not provided
      'usd': usd,
      'syp': syp,
      'tryCurrency': tryCurrency,
    };
  }

  Cashbox copyWith({int? id, double? usd, double? syp, double? tryCurrency}) {
    return Cashbox(
      id: id ?? this.id,
      usd: usd ?? this.usd,
      syp: syp ?? this.syp,
      tryCurrency: tryCurrency ?? this.tryCurrency,
    );
  }
}
