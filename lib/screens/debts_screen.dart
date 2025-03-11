import 'package:flutter/material.dart';
import 'package:fuel_station_app/models/cashbox.dart';
import 'package:fuel_station_app/models/debt.dart';
import 'package:fuel_station_app/database_helper.dart';

class DebtsScreen extends StatefulWidget {
  @override
  _DebtsScreenState createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Debt> _debts = [];
  String _filterStatus = 'All'; // Default filter

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  Future<void> _loadDebts({String? status}) async {
    final debtMaps = await _dbHelper.queryAll('debts');
    setState(() {
      if (status == null || status == 'All') {
        _debts = debtMaps.map((map) => Debt.fromMap(map)).toList();
      } else {
        _debts =
            debtMaps
                .where((map) => map['status'] == status)
                .map((map) => Debt.fromMap(map))
                .toList();
      }
    });
  }

  Future<void> _addOrUpdateDebt({Debt? debt}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DebtFormDialog(debt: debt),
    );

    if (result != null) {
      if (debt == null) {
        // Add new debt
        await _dbHelper.insert('debts', result);
      } else {
        // Update existing debt
        await _dbHelper.update('debts', result);
      }
      _loadDebts(); // Refresh the list
    }
  }

  Future<void> _deleteDebt(int id) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Deletion'),
            content: Text(
              'Are you sure you want to delete this debt? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Cancel
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true), // Confirm
                child: Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        // Delete the debt from the database
        await _dbHelper.delete('debts', where: 'id = ?', whereArgs: [id]);

        // Reload debts to reflect changes
        _loadDebts();

        // Show success message
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Debt deleted successfully.')));
      } catch (e) {
        // Handle errors
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete debt: $e')));
      }
    }
  }

  Future<void> _updateCashbox(double amount, String currency) async {
    final cashboxMaps = await _dbHelper.queryAll('cashbox');
    if (cashboxMaps.isNotEmpty) {
      final cashbox = Cashbox.fromMap(cashboxMaps.first);
      double usd = cashbox.usd;
      double syp = cashbox.syp;
      double tryCurrency = cashbox.tryCurrency;

      if (currency == 'USD') {
        usd += amount;
      } else if (currency == 'SYP') {
        syp += amount;
      } else if (currency == 'TRY') {
        tryCurrency += amount;
      }

      final updatedCashbox = Cashbox(
        usd: usd,
        syp: syp,
        tryCurrency: tryCurrency,
      );
      final updatedMap = updatedCashbox.toMap();
      updatedMap['id'] = 1; // Ensure the ID is included
      await _dbHelper.update('cashbox', updatedMap);
    }
  }

  Future<void> _markDebtAsPaid(Debt debt) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Payment'),
            content: Text('Mark this debt as paid?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Cancel
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true), // Confirm
                child: Text('Confirm'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        // Transfer the debt amount to the cashbox
        await _updateCashbox(debt.totalDebt, debt.currency);

        // Add a transaction for the debt payment
        final note = 'Debt payment for customer ${debt.customerName}';
        final transactionData = {
          'currency': debt.currency,
          'amount': debt.totalDebt,
          'type': 'Deposit',
          'date': DateTime.now().toIso8601String(),
          'note': note,
        };
        await _dbHelper.insert('transactions', transactionData);

        // Update the debt status to "Paid"
        final updatedDebt = {
          'id': debt.id,
          'customerName': debt.customerName,
          'totalDebt': debt.totalDebt,
          'currency': debt.currency,
          'date': debt.date,
          'status': 'Paid',
        };
        await _dbHelper.update('debts', updatedDebt);

        // Reload data to reflect changes
        _loadDebts();

        // Show success message
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Payment confirmed.')));
      } catch (e) {
        // Handle errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process payment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Debts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter by Status:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _filterStatus,
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value!;
                    });
                    _loadDebts(status: value == 'All' ? null : value);
                  },
                  items:
                      ['All', 'Outstanding', 'Paid'].map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _debts.isEmpty
                    ? Center(child: Text('No debts available.'))
                    : ListView.builder(
                      itemCount: _debts.length,
                      itemBuilder: (context, index) {
                        final debt = _debts[index];
                        return _buildDebtCard(debt);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(Debt debt) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Debt #${debt.id}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _addOrUpdateDebt(debt: debt),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed:
                          () => _deleteDebt(
                            debt.id!,
                          ), // Trigger delete with confirmation
                    ),
                    if (debt.status == 'Outstanding')
                      ElevatedButton(
                        onPressed: () => _markDebtAsPaid(debt),
                        child: Text('Mark Paid'),
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('Customer: ${debt.customerName}'),
            Text(
              'Total Debt: ${debt.totalDebt.toStringAsFixed(2)} ${debt.currency}',
            ),
            Text('Date: ${debt.date}'),
            Text('Status: ${debt.status}'),
          ],
        ),
      ),
    );
  }
}

class DebtFormDialog extends StatefulWidget {
  final Debt? debt;

  DebtFormDialog({this.debt});

  @override
  _DebtFormDialogState createState() => _DebtFormDialogState();
}

class _DebtFormDialogState extends State<DebtFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerNameController;
  late TextEditingController _totalDebtController;
  late String _currency;
  late String _status;

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController(
      text: widget.debt?.customerName ?? '',
    );
    _totalDebtController = TextEditingController(
      text: widget.debt?.totalDebt.toString() ?? '',
    );
    _currency = widget.debt?.currency ?? 'USD';
    _status = widget.debt?.status ?? 'Outstanding';
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _totalDebtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.debt == null ? 'Add Debt' : 'Edit Debt'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _customerNameController,
              decoration: InputDecoration(labelText: 'Customer Name'),
              validator:
                  (value) =>
                      value!.isEmpty ? 'Customer name is required' : null,
            ),
            TextFormField(
              controller: _totalDebtController,
              decoration: InputDecoration(labelText: 'Total Debt'),
              keyboardType: TextInputType.number,
              validator:
                  (value) => value!.isEmpty ? 'Total debt is required' : null,
            ),
            DropdownButtonFormField<String>(
              value: _currency,
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
                  _currency = value!;
                });
              },
              validator:
                  (value) => value == null ? 'Currency is required' : null,
            ),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: InputDecoration(labelText: 'Status'),
              items:
                  ['Outstanding', 'Partially Paid', 'Paid'].map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _status = value!;
                });
              },
              validator: (value) => value == null ? 'Status is required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final debtData = {
                'id': widget.debt?.id,
                'customerName': _customerNameController.text,
                'totalDebt': double.parse(_totalDebtController.text),
                'currency': _currency,
                'date': DateTime.now().toIso8601String(),
                'status': _status,
              };
              Navigator.pop(context, debtData);
            }
          },
          child: Text(widget.debt == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
