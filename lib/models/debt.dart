class Debt {
  final int? id;
  final String customerName;
  final double totalDebt;
  final String currency;
  final String date;
  final String status;
  final String notes; // New field

  Debt({
    this.id,
    required this.customerName,
    required this.totalDebt,
    required this.currency,
    required this.date,
    required this.status,
    this.notes = '', // Default to empty string
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'totalDebt': totalDebt,
      'currency': currency,
      'date': date,
      'status': status,
      'notes': notes, // Include notes in the map
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'],
      customerName: map['customerName'],
      totalDebt: map['totalDebt'],
      currency: map['currency'],
      date: map['date'],
      status: map['status'],
      notes: map['notes'] ?? '', // Handle null values
    );
  }
}
