import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:fuel_station_app/models/cashbox.dart';
import 'package:fuel_station_app/models/invoice.dart';
import 'package:fuel_station_app/database_helper.dart';

class InvoicesScreen extends StatefulWidget {
  @override
  _InvoicesScreenState createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Invoice> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    final invoiceMaps = await _dbHelper.queryAll('invoices');
    setState(() {
      _invoices = invoiceMaps.map((map) => Invoice.fromMap(map)).toList();
    });
  }

  Future<void> _addOrUpdateInvoice({Invoice? invoice}) async {
    final tanks = await DatabaseHelper.instance.queryAll('tanks');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => InvoiceFormDialog(invoice: invoice, tanks: tanks),
    );

    if (result != null) {
      if (invoice == null) {
        // Add new invoice
        await DatabaseHelper.instance.insert('invoices', result);
      } else {
        // Update existing invoice
        await DatabaseHelper.instance.update('invoices', result);
      }

      // Handle payment status
      final paymentStatus = result['paymentStatus'];
      final totalAmount = result['totalAmount'];
      final currency = result['currency'];
      final customerName = result['customerName'];

      if (paymentStatus == 'مدفوع') {
        // Add the total amount to the cashbox
        print('Adding $totalAmount $currency to cashbox for مدفوع invoice');
        await _updateCashbox(totalAmount, currency);
      } else if (paymentStatus == 'غير مدفوع') {
        // Record the unpaid amount as a debt
        print('Recording $totalAmount $currency as debt for غير مدفوع invoice');
        await _addDebt(customerName, totalAmount, currency);
      }

      _loadInvoices(); // Refresh the list
    }
  }

  Future<void> _addDebt(
    String customerName,
    double totalAmount,
    String currency,
  ) async {
    final debtData = {
      'customerName': customerName,
      'totalDebt': totalAmount,
      'currency': currency,
      'date': DateTime.now().toIso8601String(),
      'status': 'غير مدفوع',
    };

    await DatabaseHelper.instance.insert('debts', debtData);
  }

  Future<void> _updateCashbox(double amount, String currency) async {
    final cashboxMaps = await DatabaseHelper.instance.queryAll('cashbox');
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
      await DatabaseHelper.instance.update('cashbox', updatedMap);
    }
  }

  Future<void> _deleteInvoice(int id) async {
    await _dbHelper.database.then(
      (db) => db.delete('invoices', where: 'id = ?', whereArgs: [id]),
    );
    _loadInvoices(); // Refresh the list
  }

  Future<void> _updatePaymentStatus(int id, String status) async {
    // Update the invoice's payment status
    await DatabaseHelper.instance.update('invoices', {
      'id': id,
      'paymentStatus': status,
    });

    // If the status is changed to "مدفوع", transfer the debt to the cashbox
    if (status == 'مدفوع') {
      final invoiceMaps = await DatabaseHelper.instance.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (invoiceMaps.isNotEmpty) {
        final invoice = Invoice.fromMap(invoiceMaps.first);

        // Check if the invoice was previously unpaid
        if (invoice.paymentStatus == 'غير مدفوع') {
          // Add the total amount to the cashbox
          print(
            'Transferring $invoice.totalAmount $invoice.currency to cashbox for مدفوع invoice',
          );
          await _updateCashbox(invoice.totalAmount, invoice.currency);

          // Update the debt status to "مدفوع"
          final debts = await DatabaseHelper.instance.query(
            'debts',
            where:
                'customerName = ? AND totalDebt = ? AND currency = ? AND status = ?',
            whereArgs: [
              invoice.customerName,
              invoice.totalAmount,
              invoice.currency,
              'غير مدفوع',
            ],
          );
          if (debts.isNotEmpty) {
            final debtId = debts.first['id'];
            await DatabaseHelper.instance.update('debts', {
              'id': debtId,
              'status': 'مدفوع',
            });
          }
        }
      }
    }

    _loadInvoices(); // Refresh the list
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('الفواتير'),
          actions: [
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () => _addOrUpdateInvoice(),
            ),
          ],
        ),
        body:
            _invoices.isEmpty
                ? Center(child: Text('لا يوجد فواتير !'))
                : ListView.builder(
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = _invoices[index];
                    return _buildInvoiceCard(invoice);
                  },
                ),
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
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
                  'الفاتورة رقم #${invoice.id}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _addOrUpdateInvoice(invoice: invoice),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteInvoice(invoice.id!),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('الزبون: ${invoice.customerName}'),
            Text('نوع الوقود: ${invoice.fuelType}'),
            Text('الكميّة: ${invoice.quantity}L'),
            Text('سعر اللتر: ${invoice.pricePerUnit}'),
            Text(
              ' المبلغ الإجمالي: ${invoice.totalAmount} ${invoice.currency}',
            ),
            Text('التاريخ: ${invoice.date}'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('Status: ${invoice.paymentStatus}')],
            ),
          ],
        ),
      ),
    );
  }
}

class InvoiceFormDialog extends StatefulWidget {
  final Invoice? invoice;
  final List<Map<String, dynamic>> tanks; // Pass the list of tanks

  InvoiceFormDialog({this.invoice, required this.tanks});

  @override
  _InvoiceFormDialogState createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends State<InvoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerNameController;
  late String _selectedTankId;
  late TextEditingController _quantityController;
  late TextEditingController _pricePerUnitController;
  late String _currency;
  late String _paymentStatus;

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController(
      text: widget.invoice?.customerName ?? '',
    );
    _selectedTankId = widget.invoice?.fuelType ?? widget.tanks.first['id'];
    _quantityController = TextEditingController(
      text: widget.invoice?.quantity.toString() ?? '',
    );
    _pricePerUnitController = TextEditingController(
      text: widget.invoice?.pricePerUnit.toString() ?? '',
    );
    _currency = widget.invoice?.currency ?? 'USD';
    _paymentStatus = widget.invoice?.paymentStatus ?? 'غير مدفوع';
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _quantityController.dispose();
    _pricePerUnitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.invoice == null ? 'إضافة فاتورة' : 'تعديل فاتورة'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _customerNameController,
              decoration: InputDecoration(labelText: 'إسم الزبون'),
              validator: (value) => value!.isEmpty ? 'إسم الزبون مطلوب' : null,
            ),
            DropdownButtonFormField<String>(
              value: _selectedTankId,
              decoration: InputDecoration(labelText: 'خزان الوقود'),
              items:
                  widget.tanks.map((tank) {
                    return DropdownMenuItem<String>(
                      value: tank['id'],
                      child: Text(
                        '${tank['fuelType']} Tank (${tank['id']}) - ${tank['currentLevel']}L',
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTankId = value!;
                });
              },
              validator: (value) => value == null ? 'خزان الوقود مطلوب' : null,
            ),
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(labelText: 'الكمية باللتر'),
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty ? 'الكميّة مطلوبة' : null,
            ),
            TextFormField(
              controller: _pricePerUnitController,
              decoration: InputDecoration(labelText: 'سعر اللتر'),
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty ? 'سعر اللتر مطلوب ' : null,
            ),
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
              onChanged: (value) {
                setState(() {
                  _currency = value!;
                });
              },
              validator: (value) => value == null ? 'العملة مطلوبة' : null,
            ),
            DropdownButtonFormField<String>(
              value: _paymentStatus,
              decoration: InputDecoration(labelText: 'حالة الدفع'),
              items:
                  ['غير مدفوع', 'مدفوع'].map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _paymentStatus = value!;
                });
              },
              validator: (value) => value == null ? 'حالة الدفع مطلوبة' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء '),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final selectedTank = widget.tanks.firstWhere(
                (tank) => tank['id'] == _selectedTankId,
              );
              final quantity = double.parse(_quantityController.text);

              // Check if the tank has sufficient fuel
              if (quantity > selectedTank['currentLevel']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('لا يوجد وقود كافي في الخزان ')),
                );
                return;
              }

              final totalAmount =
                  quantity * double.parse(_pricePerUnitController.text);
              final invoiceData = {
                'id': widget.invoice?.id,
                'customerName': _customerNameController.text,
                'fuelType': selectedTank['fuelType'],
                'quantity': quantity,
                'pricePerUnit': double.parse(_pricePerUnitController.text),
                'totalAmount': totalAmount,
                'currency': _currency,
                'date': DateTime.now().toIso8601String(),
                'paymentStatus': _paymentStatus,
              };

              // Deduct fuel from the tank
              await _updateTank(
                selectedTank['id'],
                selectedTank['currentLevel'] - quantity,
              );

              // Update the digital counter of the connected pump
              final pump = await _getConnectedPump(selectedTank['id']);
              if (pump != null) {
                await _updatePump(
                  pump['id'],
                  pump['digitalCounter'] + quantity,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('لا يوجد مضحة متصلة بالخزان ')),
                );
              }

              // Handle payment status
              if (_paymentStatus == 'مدفوع') {
                // Add the total amount to the cashbox
                print(
                  'إضافة  $totalAmount $_currency إلى الصندوق كفاتورة مدفوعة ',
                );
                await _updateCashbox(totalAmount, _currency);
              } else if (_paymentStatus == 'غير مدفوع') {
                // Record the unpaid amount as a debt
                print(
                  'Recording $totalAmount $_currency as debt for غير مدفوع invoice',
                );
                await _addDebt(
                  _customerNameController.text,
                  totalAmount,
                  _currency,
                );
              }

              Navigator.pop(context, invoiceData);
            }
          },
          child: Text(widget.invoice == null ? 'إضافة ' : 'حفظ'),
        ),
      ],
    );
  }

  Future<void> _updateTank(String tankId, double newCurrentLevel) async {
    await DatabaseHelper.instance.update('tanks', {
      'id': tankId,
      'currentLevel': newCurrentLevel,
    });
  }

  // Import the collection package

  Future<Map<String, dynamic>?> _getConnectedPump(String tankId) async {
    final pumps = await DatabaseHelper.instance.queryAll('pumps');
    return pumps.firstWhereOrNull((pump) => pump['connectedTankId'] == tankId);
  }

  Future<void> _updatePump(String pumpId, double newDigitalCounter) async {
    await DatabaseHelper.instance.update('pumps', {
      'id': pumpId,
      'digitalCounter': newDigitalCounter,
    });
  }

  Future<void> _updateCashbox(double amount, String currency) async {
    final cashboxMaps = await DatabaseHelper.instance.queryAll('cashbox');
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
      await DatabaseHelper.instance.update('cashbox', updatedMap);
    }
  }

  Future<void> _addDebt(
    String customerName,
    double totalAmount,
    String currency,
  ) async {
    final debtData = {
      'customerName': customerName,
      'totalDebt': totalAmount,
      'currency': currency,
      'date': DateTime.now().toIso8601String(),
      'status': 'غير مدفوع',
    };
  }
}
