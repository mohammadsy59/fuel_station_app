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
  String _filterStatus = 'الجميع'; // Default filter
  Cashbox? _cashbox; // Add this variable

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load debts
    final debtMaps = await _dbHelper.queryAll('debts');
    // Load cashbox
    final cashboxMaps = await _dbHelper.queryAll('cashbox');
    setState(() {
      _debts = debtMaps.map((map) => Debt.fromMap(map)).toList();
      _cashbox =
          cashboxMaps.isNotEmpty
              ? Cashbox.fromMap(cashboxMaps.first)
              : Cashbox(usd: 0, syp: 0, tryCurrency: 0);
    });
  }

  Future<void> _loadDebts({String? status}) async {
    final debtMaps = await _dbHelper.queryAll('debts');
    setState(() {
      if (status == null || status == 'الجميع') {
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

  Future<void> _addOrUpdateDebt({Map<String, dynamic>? debtData}) async {
    try {
      if (debtData != null) {
        final isCashWithdrawal = debtData['isCashWithdrawal'] ?? false;
        final currency = debtData['currency'];
        final amount = debtData['totalDebt'];

        if (isCashWithdrawal) {
          // Fetch cashbox
          final cashboxMaps = await _dbHelper.queryAll('cashbox');
          if (cashboxMaps.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Cashbox not initialized!')));
            return;
          }
          final cashbox = Cashbox.fromMap(cashboxMaps.first);

          // Deduct from cashbox
          final updatedCashbox = _deductFromCashbox(cashbox, currency, amount);

          // Include the ID in the map to ensure the correct row is updated
          final updatedMap = updatedCashbox.toMap();
          updatedMap['id'] = 1; // Assuming the cashbox has a fixed ID of 1

          await _dbHelper.update('cashbox', updatedMap);
        }

        // Insert debt into the database
        await _dbHelper.insert('debts', {
          'customerName': debtData['customerName'],
          'totalDebt': debtData['totalDebt'],
          'currency': debtData['currency'],
          'date': DateTime.now().toIso8601String(),
          'status': 'غير مدفوع',
        });

        _loadData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم اضافة الدين بنجاح')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل اضافة الدين $e')));
    }
  }

  // Deduct from cashbox based on currency
  Cashbox _deductFromCashbox(Cashbox cashbox, String currency, double amount) {
    switch (currency) {
      case 'USD':
        return cashbox.copyWith(usd: cashbox.usd - amount);
      case 'SYP':
        return cashbox.copyWith(syp: cashbox.syp - amount);
      case 'TRY':
        return cashbox.copyWith(tryCurrency: cashbox.tryCurrency - amount);
      default:
        return cashbox;
    }
  }

  Future<void> _deleteDebt(int id) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تأكيد الحذف؟'),
            content: Text(
              'هل فعلا تريد حذف هذا الدين ؟ لا يمكن التراجع عن هذا ',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Cancel
                child: Text('إلغاء '),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true), // Confirm
                child: Text('حذف'),
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
        ).showSnackBar(SnackBar(content: Text('تم حذف الدين بنجاح ')));
      } catch (e) {
        // Handle errors
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل حذف الدين: $e')));
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
            title: Text('تأكيد الدفع'),
            content: Text('نحديد هذا الدين على أنه مدفوع ؟.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Cancel
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true), // Confirm
                child: Text('تأكيد'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        // Transfer the debt amount to the cashbox
        await _updateCashbox(debt.totalDebt, debt.currency);

        // Add a transaction for the debt payment
        final note = 'تم الدفع من قبل  ${debt.customerName}';
        final transactionData = {
          'currency': debt.currency,
          'amount': debt.totalDebt,
          'type': 'ايداع',
          'date': DateTime.now().toIso8601String(),
          'note': note,
        };
        await _dbHelper.insert('transactions', transactionData);

        // Update the debt status to "مدفوع"
        final updatedDebt = {
          'id': debt.id,
          'customerName': debt.customerName,
          'totalDebt': debt.totalDebt,
          'currency': debt.currency,
          'date': debt.date,
          'status': 'مدفوع',
        };
        await _dbHelper.update('debts', updatedDebt);

        // Reload data to reflect changes
        _loadDebts();

        // Show success message
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم تأكيد الدفع.')));
      } catch (e) {
        // Handle errors
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشلت عملية الدفع: $e')));
      }
    }
  }

  Future<void> _addStandardDebt() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DebtFormDialog(debt: null, cashbox: _cashbox!),
    );
    if (result != null) {
      await _addOrUpdateDebt(debtData: result);
    }
  }

  // Method for Cash سحب Debt
  Future<void> _addCashWithdrawalDebt() async {
    final cashboxMaps = await _dbHelper.queryAll('cashbox');
    if (cashboxMaps.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cashbox not initialized!')));
      return;
    }
    final cashbox = Cashbox.fromMap(cashboxMaps.first);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CashWithdrawalDebtDialog(cashbox: cashbox),
    );

    if (result != null) {
      await _addOrUpdateDebt(debtData: result);
    }
  }

  Future<void> _showDebtTypeDialog() async {
    final selectedType = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Select Debt Type'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Standard Debt'),
                  onTap: () => Navigator.pop(context, 'standard'),
                ),
                ListTile(
                  title: Text('Cash Withdrawal Debt'),
                  onTap: () => Navigator.pop(context, 'cash_withdrawal'),
                ),
              ],
            ),
          ),
    );

    if (selectedType == 'standard') {
      _addStandardDebt();
    } else if (selectedType == 'cash_withdrawal') {
      _addCashWithdrawalDebt();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('الديون')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تصفية حسب :',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: _filterStatus,
                    onChanged: (value) {
                      setState(() {
                        _filterStatus = value!;
                      });
                      _loadDebts(status: value == 'الجميع' ? null : value);
                    },
                    items:
                        ['الجميع', 'غير مدفوع', 'مدفوع'].map((status) {
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
                      ? Center(child: Text('لا يوجد ديون !'))
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
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showDebtTypeDialog(),
          child: Icon(Icons.add),
          backgroundColor: Colors.blue[700],
        ),
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
                  'الدين رقم #${debt.id}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _addOrUpdateDebt(),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteDebt(debt.id!),
                    ),
                    if (debt.status == 'غير مدفوع')
                      ElevatedButton(
                        onPressed: () => _markDebtAsPaid(debt),
                        child: Text('تحديد كمدفوع'),
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('الزبون : ${debt.customerName}'),
            Text(
              'قيمة الدين: ${debt.totalDebt.toStringAsFixed(2)} ${debt.currency}',
            ),
            Text('بتاريخ: ${debt.date}'),
            Text('الحالة : ${debt.status}'),
            if (debt.notes.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text(
                    'ملاحظات :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(debt.notes, style: TextStyle(fontSize: 14)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class DebtFormDialog extends StatefulWidget {
  final Debt? debt;
  final Cashbox? cashbox; // Pass cashbox for validation
  final String debtType; // Add this to pass the debt type from FAB

  DebtFormDialog({this.debt, required this.cashbox, required this.debtType});

  @override
  _DebtFormDialogState createState() => _DebtFormDialogState();
}

class _DebtFormDialogState extends State<DebtFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerNameController;
  late TextEditingController _totalDebtController;
  late TextEditingController _notesController;
  String _currency = 'USD';
  String _status = 'غير مدفوع';
  String _debtType = 'دين بدون سحب من الصندوق'; // Default to Fuel Debt

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController(
      text: widget.debt?.customerName ?? '',
    );
    _totalDebtController = TextEditingController(
      text: widget.debt?.totalDebt.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.debt?.notes ?? '');
    _currency = widget.debt?.currency ?? 'USD';
    _status = widget.debt?.status ?? 'غير مدفوع';
    _debtType =
        widget.debt != null
            ? 'دين بدون سجب من الصندوق'
            : _debtType; // Disable type change for existing debts
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.debt == null ? 'اضافة دين' : 'تعديل دين'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Debt Type Dropdown

              // Customer Name
              TextFormField(
                controller: _customerNameController,
                decoration: InputDecoration(labelText: 'اسم الزبون'),
                validator:
                    (value) => value!.isEmpty ? 'اسم الزبون مطلوب' : null,
              ),
              // Total Debt
              TextFormField(
                controller: _totalDebtController,
                decoration: InputDecoration(labelText: 'قيمة الدين'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'قيمة الدين مطلوبة';
                  final amount = double.tryParse(value) ?? 0;
                  if (_debtType == 'دين مع سحب من الصندوق') {
                    final cashbox = widget.cashbox!;
                    final availableBalance = _getAvailableBalance(
                      cashbox,
                      _currency,
                    );
                    if (amount > availableBalance) {
                      return 'لا يوجد نقود كافية فيى الصندوق';
                    }
                  }
                  return null;
                },
              ),
              // Currency
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: InputDecoration(labelText: 'العملة'),
                items:
                    ['USD', 'SYP', 'TRY'].map((currency) {
                      return DropdownMenuItem<String>(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => _currency = value!),
                validator: (value) => value == null ? 'نوع العملة مطلوب' : null,
              ),
              // Notes
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(labelText: 'ملاحظات (اختياري)'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
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
                  'notes': _notesController.text.trim(),
                  'type': _debtType, // Include debt type in the result
                };
                Navigator.pop(context, debtData);
              }
            },
            child: Text(widget.debt == null ? 'اضافة' : 'حفظ'),
          ),
        ],
      ),
    );
  }

  // Helper method to get available balance for validation
  double _getAvailableBalance(Cashbox cashbox, String currency) {
    switch (currency) {
      case 'USD':
        return cashbox.usd;
      case 'SYP':
        return cashbox.syp;
      case 'TRY':
        return cashbox.tryCurrency;
      default:
        return 0;
    }
  }
}

class ManualDebtDialog extends StatefulWidget {
  @override
  _ManualDebtDialogState createState() => _ManualDebtDialogState();
}

class _ManualDebtDialogState extends State<ManualDebtDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _totalDebtController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  String _selectedCurrency = 'USD';
  String _selectedStatus = 'غير مدفوع';

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toIso8601String().split('T')[0];
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _totalDebtController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('اضافة دين يدوياً'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _customerNameController,
                decoration: InputDecoration(labelText: 'اسم الزبون'),
                validator:
                    (value) => value!.isEmpty ? 'اسم الزبون مطلوب' : null,
              ),
              TextFormField(
                controller: _totalDebtController,
                decoration: InputDecoration(labelText: 'قيمة الدين'),
                keyboardType: TextInputType.number,
                validator:
                    (value) => value!.isEmpty ? 'قيمة الدين مطلوبة ' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                decoration: InputDecoration(labelText: 'العملة '),
                items:
                    ['USD', 'SYP', 'TRY'].map((currency) {
                      return DropdownMenuItem<String>(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                onChanged:
                    (value) => setState(() => _selectedCurrency = value!),
                validator: (value) => value == null ? 'نوع العملة مطلوب' : null,
              ),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(labelText: 'التاريخ'),
                readOnly: true,
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _dateController.text =
                          pickedDate.toIso8601String().split('T')[0];
                    });
                  }
                },
                validator: (value) => value!.isEmpty ? 'التاريخ مطلوب' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(labelText: 'الحالة '),
                items:
                    ['غير مدفوع', 'مدفوع'].map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => _selectedStatus = value!),
                validator: (value) => value == null ? 'الحالة مطلوبة' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final debtData = {
                  'customerName': _customerNameController.text,
                  'totalDebt': double.parse(_totalDebtController.text),
                  'currency': _selectedCurrency,
                  'date': _dateController.text,
                  'status': _selectedStatus,
                };
                Navigator.pop(context, debtData);
              }
            },
            child: Text('اضافة دين'),
          ),
        ],
      ),
    );
  }
}

class CashWithdrawalDebtDialog extends StatefulWidget {
  final Cashbox cashbox;

  CashWithdrawalDebtDialog({required this.cashbox});

  @override
  _CashWithdrawalDebtDialogState createState() =>
      _CashWithdrawalDebtDialogState();
}

class _CashWithdrawalDebtDialogState extends State<CashWithdrawalDebtDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerNameController;
  late TextEditingController _amountController;
  String _currency = 'USD';

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController();
    _amountController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('اضافة دين مع سحب من الصندوق'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _customerNameController,
                decoration: InputDecoration(labelText: 'الموظف/اسم الزبون'),
                validator: (value) => value!.isEmpty ? 'الإسم مطلوب' : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(labelText: 'المبلغ المسحوب'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'المبلغ مطلوب';
                  final amount = double.tryParse(value) ?? 0;
                  final available = _getAvailableBalance(
                    widget.cashbox,
                    _currency,
                  );
                  if (amount > available) return 'لا توجد نقود كافية ';
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: InputDecoration(labelText: 'العملة '),
                items:
                    ['USD', 'SYP', 'TRY'].map((currency) {
                      return DropdownMenuItem<String>(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => _currency = value!),
                validator: (value) => value == null ? 'العملة مطلوبة ' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final amount = double.parse(_amountController.text);
                final customerName = _customerNameController.text;
                final currency = _currency;

                // Remove 'notes' and 'isCashWithdrawal' from the result
                Navigator.pop(context, {
                  'customerName': customerName,
                  'totalDebt': amount,
                  'currency': currency,
                  'isCashWithdrawal': true, // Include this flag
                });
              }
            },
            child: Text('سحب'),
          ),
        ],
      ),
    );
  }

  // Helper method to check available cashbox balance
  double _getAvailableBalance(Cashbox cashbox, String currency) {
    switch (currency) {
      case 'USD':
        return cashbox.usd;
      case 'SYP':
        return cashbox.syp;
      case 'TRY':
        return cashbox.tryCurrency;
      default:
        return 0;
    }
  }
}
