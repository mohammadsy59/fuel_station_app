class TransactionModel {
  final int? id;
  final String currency;
  final double amount;
  final String type;
  final String date;
  final String note; // Add a note field

  TransactionModel({
    this.id,
    required this.currency,
    required this.amount,
    required this.type,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'currency': currency,
      'amount': amount,
      'type': type,
      'date': date,
      'note': note, // Include the note in the map
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      currency: map['currency'],
      amount: map['amount'],
      type: map['type'],
      date: map['date'],
      note: map['note'] ?? '', // Default to empty string if note is null
    );
  }
}
