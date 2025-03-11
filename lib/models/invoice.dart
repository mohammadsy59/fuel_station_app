class Invoice {
  final int? id;
  final String customerName;
  final String fuelType;
  final double quantity;
  final double pricePerUnit;
  final double totalAmount;
  final String currency;
  final String date;
  final String paymentStatus;

  Invoice({
    this.id,
    required this.customerName,
    required this.fuelType,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.currency,
    required this.date,
    required this.paymentStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'fuelType': fuelType,
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
      'totalAmount': totalAmount,
      'currency': currency,
      'date': date,
      'paymentStatus': paymentStatus,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      customerName: map['customerName'],
      fuelType: map['fuelType'],
      quantity: map['quantity'],
      pricePerUnit: map['pricePerUnit'],
      totalAmount: map['totalAmount'],
      currency: map['currency'],
      date: map['date'],
      paymentStatus: map['paymentStatus'],
    );
  }
}
