class Cashbox {
  final double usd;
  final double syp;
  final double tryCurrency; // Renamed from 'try' to 'tryCurrency'

  Cashbox({required this.usd, required this.syp, required this.tryCurrency});

  Map<String, dynamic> toMap() {
    return {
      'usd': usd,
      'syp': syp,
      'tryCurrency': tryCurrency, // Updated key
    };
  }

  factory Cashbox.fromMap(Map<String, dynamic> map) {
    return Cashbox(
      usd: map['usd']?.toDouble() ?? 0.0,
      syp: map['syp']?.toDouble() ?? 0.0,
      tryCurrency: map['tryCurrency']?.toDouble() ?? 0.0, // Updated key
    );
  }
  Cashbox copyWith({double? usd, double? syp, double? tryCurrency}) {
    return Cashbox(
      usd: usd ?? this.usd,
      syp: syp ?? this.syp,
      tryCurrency: tryCurrency ?? this.tryCurrency,
    );
  }
}
