import 'package:flutter/material.dart';
import 'package:fuel_station_app/models/cashbox.dart';
import 'package:fuel_station_app/database_helper.dart';
import 'package:fuel_station_app/models/transaction.dart';

class CashboxScreen extends StatefulWidget {
  @override
  _CashboxScreenState createState() => _CashboxScreenState();
}

class _CashboxScreenState extends State<CashboxScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  Cashbox? _cashbox;
  List<TransactionModel> _transactions =
      []; // Declare as List<TransactionModel>

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load cashbox
    final cashboxMaps = await _dbHelper.queryAll('cashbox');
    if (cashboxMaps.isNotEmpty) {
      setState(() {
        _cashbox = Cashbox.fromMap(cashboxMaps.first);
      });
    }

    // Load transactions
    final transactionMaps = await _dbHelper.queryAll('transactions');
    setState(() {
      _transactions =
          transactionMaps.map((map) => TransactionModel.fromMap(map)).toList();
    });
  }

  Future<void> _updateBalance(String currency, double newValue) async {
    if (_cashbox == null) return;

    // Create a new Cashbox object with the updated value
    final updatedCashbox = Cashbox(
      usd: currency == 'USD' ? newValue : _cashbox!.usd,
      syp: currency == 'SYP' ? newValue : _cashbox!.syp,
      tryCurrency: currency == 'TRY' ? newValue : _cashbox!.tryCurrency,
    );

    // Convert to map and include the ID
    final updatedMap = updatedCashbox.toMap();
    updatedMap['id'] = 1; // Ensure the ID is included

    // Update the database
    await _dbHelper.update('cashbox', updatedMap);

    // Reload data to reflect changes
    _loadData();
  }

  Future<void> _addTransaction(TransactionModel transaction) async {
    // Insert the transaction into the database
    await _dbHelper.insert('transactions', transaction.toMap());

    // Update the cashbox balance based on the transaction type
    if (_cashbox != null) {
      double newUsd = _cashbox!.usd;
      double newSyp = _cashbox!.syp;
      double newTryCurrency = _cashbox!.tryCurrency;

      if (transaction.currency == 'USD') {
        if (transaction.type == 'ايداع') {
          newUsd += transaction.amount; // Add for deposit
        } else if (transaction.type == 'سحب') {
          newUsd -= transaction.amount; // Subtract for withdrawal
        }
      } else if (transaction.currency == 'SYP') {
        if (transaction.type == 'ايداع') {
          newSyp += transaction.amount;
        } else if (transaction.type == 'سحب') {
          newSyp -= transaction.amount;
        }
      } else if (transaction.currency == 'TRY') {
        if (transaction.type == 'ايداع') {
          newTryCurrency += transaction.amount;
        } else if (transaction.type == 'سحب') {
          newTryCurrency -= transaction.amount;
        }
      }

      // Create an updated Cashbox object
      final updatedCashbox = Cashbox(
        usd: newUsd,
        syp: newSyp,
        tryCurrency: newTryCurrency,
      );

      // Update the cashbox in the database
      final updatedMap = updatedCashbox.toMap();
      updatedMap['id'] = 1; // Ensure the ID is included
      await _dbHelper.update('cashbox', updatedMap);

      // Reload data to reflect changes
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('إدارة الصندوق'),
          actions: [
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () => _showTransactionDialog(),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('الميزانية'),
              _buildBalanceCards(),
              SizedBox(height: 20),
              _buildSectionTitle('المعاملات الأخيرة'),
              _transactions.isEmpty
                  ? Center(child: Text('لا يوجد معاملات'))
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _transactions[index];
                      return _buildTransactionCard(
                        transaction,
                      ); // Pass the TransactionModel object
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBalanceCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildBalanceCard(
          'USD',
          '\$${_cashbox?.usd.toStringAsFixed(2) ?? '0.00'}',
          Colors.green,
        ),
        _buildBalanceCard(
          'SYP',
          '${_cashbox?.syp.toStringAsFixed(2) ?? '0.00'}',
          Colors.orange,
        ),
        _buildBalanceCard(
          'TRY',
          '₺${_cashbox?.tryCurrency.toStringAsFixed(2) ?? '0.00'}',
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildBalanceCard(String currency, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showUpdateBalanceDialog(currency),
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currency,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transaction.type} (${transaction.currency})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('المبلغ: ${transaction.amount}'),
            Text('التاريخ: ${DateTime.parse(transaction.date).toString()}'),
            if (transaction.note.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text(
                    'ملاحظة : ${transaction.note}',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showUpdateBalanceDialog(String currency) {
    final TextEditingController _amountController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تعديل $currency '),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'المبلغ'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _amountController.dispose(); // Clean up the controller
                  Navigator.pop(context); // Close the dialog
                },
                child: Text('الفاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(_amountController.text) ?? 0.0;
                  _updateBalance(currency, amount); // Update the balance
                  _amountController.dispose(); // Clean up the controller
                  Navigator.pop(context); // Close the dialog
                },
                child: Text('حفظ'),
              ),
            ],
          ),
    );
  }

  void _showTransactionDialog() {
    final TextEditingController _amountController = TextEditingController();
    final TextEditingController _noteController = TextEditingController();
    String? _selectedCurrency = 'USD';
    String? _selectedType = 'ايداع';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('اضافة معاملة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCurrency,
                  decoration: InputDecoration(labelText: 'العملة'),
                  items:
                      ['USD', 'SYP', 'TRY'].map((currency) {
                        return DropdownMenuItem<String>(
                          value: currency,
                          child: Text(currency),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCurrency = value!;
                    });
                  },
                ),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'المبلغ'),
                ),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(labelText: 'النوع'),
                  items:
                      ['ايداع', 'سحب'].map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(labelText: 'ملاحظات (اختياري)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _amountController.dispose();
                  _noteController.dispose();
                  Navigator.pop(context); // Close the dialog
                },
                child: Text('الغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(_amountController.text);
                  if (amount == null || amount == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('الرجاء ادخال قيمة صحيحة')),
                    );
                    return;
                  }

                  // Create a new transaction
                  final transaction = TransactionModel(
                    currency: _selectedCurrency!,
                    amount: amount,
                    type: _selectedType!,
                    date: DateTime.now().toIso8601String(),
                    note:
                        _noteController.text
                            .trim(), // Trim whitespace from the note
                  );

                  // Insert the transaction into the database
                  _addTransaction(transaction);

                  _amountController.dispose();
                  _noteController.dispose();
                  Navigator.pop(context); // Close the dialog
                },
                child: Text('اضافة'),
              ),
            ],
          ),
    );
  }
}
