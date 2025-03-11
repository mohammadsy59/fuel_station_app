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
        if (transaction.type == 'Deposit') {
          newUsd += transaction.amount; // Add for deposit
        } else if (transaction.type == 'Withdrawal') {
          newUsd -= transaction.amount; // Subtract for withdrawal
        }
      } else if (transaction.currency == 'SYP') {
        if (transaction.type == 'Deposit') {
          newSyp += transaction.amount;
        } else if (transaction.type == 'Withdrawal') {
          newSyp -= transaction.amount;
        }
      } else if (transaction.currency == 'TRY') {
        if (transaction.type == 'Deposit') {
          newTryCurrency += transaction.amount;
        } else if (transaction.type == 'Withdrawal') {
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Cashbox Management'),
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
            _buildSectionTitle('Balances'),
            _buildBalanceCards(),
            SizedBox(height: 20),
            _buildSectionTitle('Recent Transactions'),
            _transactions.isEmpty
                ? Center(child: Text('No transactions available.'))
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
          width: 100,
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
            Text('Amount: ${transaction.amount}'),
            Text('Date: ${DateTime.parse(transaction.date).toString()}'),
            if (transaction.note.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text(
                    'Note: ${transaction.note}',
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
            title: Text('Update $currency Balance'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Amount'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _amountController.dispose(); // Clean up the controller
                  Navigator.pop(context); // Close the dialog
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(_amountController.text) ?? 0.0;
                  _updateBalance(currency, amount); // Update the balance
                  _amountController.dispose(); // Clean up the controller
                  Navigator.pop(context); // Close the dialog
                },
                child: Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showTransactionDialog() {
    final TextEditingController _amountController = TextEditingController();
    final TextEditingController _noteController = TextEditingController();
    String? _selectedCurrency = 'USD';
    String? _selectedType = 'Deposit';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Transaction'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCurrency,
                  decoration: InputDecoration(labelText: 'Currency'),
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
                  decoration: InputDecoration(labelText: 'Amount'),
                ),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(labelText: 'Type'),
                  items:
                      ['Deposit', 'Withdrawal'].map((type) {
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
                  decoration: InputDecoration(labelText: 'Note (Optional)'),
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
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(_amountController.text);
                  if (amount == null || amount == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a valid amount')),
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
                child: Text('Add'),
              ),
            ],
          ),
    );
  }
}
