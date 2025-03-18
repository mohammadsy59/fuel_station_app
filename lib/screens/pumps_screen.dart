import 'package:flutter/material.dart';
import 'package:fuel_station_app/models/cashbox.dart';
import 'package:fuel_station_app/models/pump.dart';
import 'package:fuel_station_app/models/tank.dart';
import 'package:fuel_station_app/database_helper.dart';

class PumpsScreen extends StatefulWidget {
  @override
  _PumpsScreenState createState() => _PumpsScreenState();
}

class _PumpsScreenState extends State<PumpsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Pump> _pumps = [];
  List<Map<String, dynamic>> _tanks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load pumps
    final pumpMaps = await _dbHelper.queryAll('pumps');
    setState(() {
      _pumps = pumpMaps.map((map) => Pump.fromMap(map)).toList();
    });

    // Load tanks for dropdown
    final tankMaps = await _dbHelper.queryAll('tanks');
    setState(() {
      _tanks = tankMaps;
    });
  }

  Future<void> _addOrUpdatePump({Pump? pump}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => PumpFormDialog(pump: pump, tanks: _tanks, pumps: _pumps),
    );
    if (result != null) {
      if (pump == null) {
        await _dbHelper.insert('pumps', result);
      } else {
        await _dbHelper.update('pumps', result);
      }
      _loadData(); // Refresh the list
    }
  }

  Future<void> _deletePump(String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تأكيد الحذف '),
            content: Text('هل تريد بالفعل حذف المضخة ؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('إلغاء '),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('حذف'),
              ),
            ],
          ),
    );
    if (shouldDelete != true) return;
    try {
      await _dbHelper.database.then(
        (db) => db.delete('pumps', where: 'id = ?', whereArgs: [id]),
      );
      _loadData(); // Refresh the list
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم جذف المضخة بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل حذف المضخة : $e')));
    }
  }

  Future<void> _sellFuel(Pump pump) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SellFuelDialog(pump: pump),
    );

    if (result != null) {
      try {
        final currentDigitalCounter = result['currentDigitalCounter'];
        final pricePerLiter = result['pricePerLiter'];
        final paidAmount = result['paidAmount']; // Ensure this is parsed
        final currency = result['currency'];
        final customerName = result['customerName'];

        // Fetch previous pump data
        final pumpMap = await _dbHelper.query(
          'pumps',
          where: 'id = ?',
          whereArgs: [pump.id],
        );
        if (pumpMap.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('المضخة غير موجودة')));
          return;
        }

        final previousDigitalCounter =
            pumpMap.first['digitalCounter'] as double;
        final previousMechanicalCounter =
            pumpMap.first['mechanicalCounter'] as double;

        // Calculate fuel sold
        // Calculate fuel sold
        var fuelSold = _calculateSoldFuel(
          previousDigitalCounter,
          currentDigitalCounter,
        );

        // Check if the digital counter reset (if maxDigitalValue is 9999)
        if (currentDigitalCounter < previousDigitalCounter) {
          const maxDigitalValue = 9999;
          fuelSold =
              (maxDigitalValue - previousDigitalCounter) +
              currentDigitalCounter;
        }

        // Fetch connected tank
        final tankMap = await _dbHelper.query(
          'tanks',
          where: 'id = ?',
          whereArgs: [pump.connectedTankId],
        );
        if (tankMap.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('الخزان المتصلة به المضخة غير موجود!')),
          );
          return;
        }

        final tank = Tank.fromMap(tankMap.first);

        // Check if there's enough fuel
        if (tank.currentLevel < fuelSold) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('لا يوجد وقود كافي في الخزان!')),
          );
          return;
        }

        // Update tank's current level
        final updatedTank = tank.copyWith(
          currentLevel: tank.currentLevel - fuelSold,
        );
        await _dbHelper.update('tanks', updatedTank.toMap());

        // Update cashbox with PAID amount
        final cashboxMaps = await _dbHelper.queryAll('cashbox');
        Cashbox cashbox;
        if (cashboxMaps.isNotEmpty) {
          cashbox = Cashbox.fromMap(cashboxMaps.first);
        } else {
          cashbox = Cashbox(usd: 0, syp: 0, tryCurrency: 0);
        }

        // Add paid amount to cashbox
        cashbox = cashbox.copyWith(
          usd: currency == 'USD' ? cashbox.usd + paidAmount : cashbox.usd,
          syp: currency == 'SYP' ? cashbox.syp + paidAmount : cashbox.syp,
          tryCurrency:
              currency == 'TRY'
                  ? cashbox.tryCurrency + paidAmount
                  : cashbox.tryCurrency,
        );
        await _dbHelper.insertOrUpdateCashbox(cashbox);

        // Record unpaid amount as debt (if any)
        final totalAmount = fuelSold * pricePerLiter;
        final unpaidAmount = totalAmount - paidAmount;
        if (unpaidAmount > 0) {
          final debtData = {
            'customerName':
                customerName, // Replace with actual customer name if needed
            'totalDebt': unpaidAmount,
            'currency': currency,
            'date': DateTime.now().toIso8601String(),
            'status': 'غير مدفوع',
          };
          await _dbHelper.insert('debts', debtData);
        }

        // Update pump counters (handle mechanical counter for resets)
        // In the _sellFuel method:
        // In the _sellFuel method:
        final newMechanicalCounter = previousMechanicalCounter + fuelSold;

        final updatedPump = pump.copyWith(
          digitalCounter: currentDigitalCounter,
          mechanicalCounter: newMechanicalCounter,
        );
        await _dbHelper.update('pumps', updatedPump.toMap());

        // Create invoice
        final invoice = {
          'customerName': customerName, // Replace with actual customer name
          'fuelType': tank.fuelType,
          'quantity': fuelSold,
          'pricePerUnit': pricePerLiter,
          'totalAmount': totalAmount,
          'currency': currency,
          'date': DateTime.now().toIso8601String(),
          'paymentStatus': unpaidAmount > 0 ? 'غير مدفوع' : 'مدفوع',
        };
        await _dbHelper.insert('invoices', invoice);

        _loadData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم البيع بنجاح!')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل البيع: $e')));
        print(e);
      }
    }
  }

  // Define the fuel calculation method
  double _calculateSoldFuel(double previousDigital, double currentDigital) {
    const maxDigitalValue = 9999;
    if (currentDigital < previousDigital) {
      return (maxDigitalValue - previousDigital) + currentDigital;
    }
    return currentDigital - previousDigital;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('مضخات الوقود'),
          actions: [
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () => _addOrUpdatePump(),
            ),
          ],
        ),
        body:
            _pumps.isEmpty
                ? Center(child: Text('لا يوجد مضخات '))
                : ListView.builder(
                  itemCount: _pumps.length,
                  itemBuilder: (context, index) {
                    final pump = _pumps[index];
                    return _buildPumpCard(pump);
                  },
                ),
      ),
    );
  }

  Widget _buildPumpCard(Pump pump) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المضخة  ${pump.id}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('متصلة بالخزان : ${pump.connectedTankId}'),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'العداد الرقمي: ${pump.digitalCounter.toStringAsFixed(2)}L',
                ),
                Text(
                  'العداد الآلي: ${pump.mechanicalCounter.toStringAsFixed(2)}L',
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _addOrUpdatePump(pump: pump),
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _deletePump(pump.id),
                ),
                IconButton(
                  icon: Icon(Icons.sell),
                  onPressed: () => _sellFuel(pump),
                ),
                IconButton(
                  icon: Icon(Icons.build), // Calibration button
                  onPressed: () => _calibratePump(pump),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _calibratePump(Pump pump) async {
    final result = await showDialog<double>(
      context: context,
      builder: (context) => CalibrationDialog(),
    );

    if (result != null) {
      try {
        final calibrationAmount = result;
        const maxDigitalValue = 9999; // Max value before reset

        // Calculate new digital counter (wrap around if needed)
        double newDigitalCounter = pump.digitalCounter + calibrationAmount;
        double newMechanicalCounter =
            pump.mechanicalCounter + calibrationAmount;

        // Handle overflow (e.g., 9999 + 1 → 0)
        if (newDigitalCounter > maxDigitalValue) {
          // Calculate how many full cycles occurred
          final cycles = (newDigitalCounter / (maxDigitalValue + 1)).floor();
          newDigitalCounter =
              newDigitalCounter % (maxDigitalValue + 1); // Reset digital
          newMechanicalCounter =
              pump.mechanicalCounter + calibrationAmount; // Add full cycles
        }

        // Update pump counters
        final updatedPump = pump.copyWith(
          digitalCounter: newDigitalCounter,
          mechanicalCounter: newMechanicalCounter,
        );
        await _dbHelper.update('pumps', updatedPump.toMap());

        _loadData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Calibration successful!')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Calibration failed: $e')));
      }
    }
  }
}

class CalibrationDialog extends StatefulWidget {
  @override
  _CalibrationDialogState createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<CalibrationDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('معايرة المضخة '),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _amountController,
          decoration: InputDecoration(labelText: 'كمية المعايرة باللتر'),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value!.isEmpty) return 'الكمية مطلوبة ';
            if (double.tryParse(value) == null) return 'رقم غير صحيح ';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إالغاء '),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final amount = double.parse(_amountController.text);
              Navigator.pop(context, amount);
            }
          },
          child: Text('المعايرة '),
        ),
      ],
    );
  }
}

class PumpFormDialog extends StatefulWidget {
  final Pump? pump;
  final List<Map<String, dynamic>> tanks;
  final List<Pump> pumps;

  PumpFormDialog({this.pump, required this.tanks, required this.pumps});

  @override
  _PumpFormDialogState createState() => _PumpFormDialogState();
}

class _PumpFormDialogState extends State<PumpFormDialog> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController;
  late TextEditingController _digitalCounterController;
  late TextEditingController _mechanicalCounterController;
  late String _selectedTankId;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.pump != null;

    // Initialize controllers
    _idController = TextEditingController(text: widget.pump?.id ?? '');
    _digitalCounterController = TextEditingController(
      text: widget.pump?.digitalCounter.toString() ?? '',
    );
    _mechanicalCounterController = TextEditingController(
      text: widget.pump?.mechanicalCounter.toString() ?? '',
    );

    // Pre-fill tank dropdown
    _selectedTankId = widget.pump?.connectedTankId ?? widget.tanks.first['id'];

    // Auto-generate ID for new pumps
    if (!_isEditMode) {
      _generateUniqueId();
    }
  }

  Future<void> _generateUniqueId() async {
    // Query the database for the highest existing ID
    final existingPumps = await _dbHelper.queryAll('pumps');
    int maxId = 0;
    for (var pump in existingPumps) {
      final id = pump['id'] as String;
      final numericPart =
          int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (numericPart > maxId) {
        maxId = numericPart;
      }
    }

    // Generate the next ID
    final nextId = 'P${maxId + 1}';
    _idController.text = nextId;
  }

  @override
  void dispose() {
    _idController.dispose();
    _digitalCounterController.dispose();
    _mechanicalCounterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.pump == null ? 'إضافة مضخة ' : 'تعديل مضخة '),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pump ID Field (Read-only)
            TextFormField(
              controller: _idController,
              decoration: InputDecoration(labelText: 'رقم المضخة '),
              enabled: false, // Disable editing
              validator: (value) {
                if (value!.isEmpty) {
                  return 'الرقم مطلوب';
                }
                if (!RegExp(r'^P\d+$').hasMatch(value)) {
                  return 'ID must start with "P" followed by a number (e.g., P1, P2)';
                }
                return null;
              },
            ),

            // Connected Tank Dropdown
            DropdownButtonFormField<String>(
              value: _selectedTankId,
              decoration: InputDecoration(labelText: 'الخزان المتصل بالمضخة '),
              items:
                  widget.tanks.map((tank) {
                    return DropdownMenuItem<String>(
                      value: tank['id'],
                      child: Text('Tank ${tank['id']} (${tank['fuelType']})'),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTankId = value!;
                });
              },
              validator:
                  (value) =>
                      value == null ? 'الخزان المتصل بالمضخة مطلوب ' : null,
            ),

            // Digital Counter Field
            TextFormField(
              controller: _digitalCounterController,
              decoration: InputDecoration(labelText: 'العداد الرقمي'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value!.isEmpty) return 'العداد الرقمي مطلوب';
                final currentDigital = double.tryParse(value) ?? 0;
                if (currentDigital > 9999)
                  return 'لا يمكن بيع اكثر من 9999 لتر !';
                return null;
              },
            ),

            // Mechanical Counter Field
            TextFormField(
              controller: _mechanicalCounterController,
              decoration: InputDecoration(labelText: 'العداد الآلي'),
              keyboardType: TextInputType.number,
              validator:
                  (value) => value!.isEmpty ? 'العداد الآلي مطلوب ' : null,
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
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final pumpData = {
                'id': _idController.text,
                'connectedTankId': _selectedTankId,
                'digitalCounter': double.parse(_digitalCounterController.text),
                'mechanicalCounter': double.parse(
                  _mechanicalCounterController.text,
                ),
              };

              // Check for duplicate ID when adding a new pump
              if (!_isEditMode) {
                final existingPump = await _dbHelper.query(
                  'pumps',
                  where: 'id = ?',
                  whereArgs: [pumpData['id']],
                );
                if (existingPump.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('رقم المضخة موجود سابقاً')),
                  );
                  return;
                }
              }

              Navigator.pop(context, pumpData);
            }
          },
          child: Text(widget.pump == null ? 'إضافة' : 'حفظ'),
        ),
      ],
    );
  }
}

class SellFuelDialog extends StatefulWidget {
  final Pump pump;

  SellFuelDialog({required this.pump});

  @override
  _SellFuelDialogState createState() => _SellFuelDialogState();
}

class _SellFuelDialogState extends State<SellFuelDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _digitalCounterController;
  late TextEditingController _pricePerLiterController;
  late TextEditingController _paidAmountController; // Ensure this exists
  late TextEditingController _customerNameController; // Ensure this exists

  String _selectedCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    _digitalCounterController = TextEditingController(
      text: widget.pump.digitalCounter.toStringAsFixed(2),
    );
    _pricePerLiterController = TextEditingController();
    _paidAmountController = TextEditingController();
    _customerNameController = TextEditingController(); // Initialize
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sell Fuel from Pump ${widget.pump.id}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _digitalCounterController,
              decoration: InputDecoration(labelText: 'Digital Counter (L)'),
              keyboardType: TextInputType.number,
              validator:
                  (value) =>
                      value!.isEmpty ? 'Digital counter is required' : null,
            ),
            TextFormField(
              controller: _pricePerLiterController,
              decoration: InputDecoration(labelText: 'Price per Liter'),
              keyboardType: TextInputType.number,
              validator:
                  (value) =>
                      value!.isEmpty ? 'Price per liter is required' : null,
            ),
            TextFormField(
              controller: _customerNameController,
              decoration: InputDecoration(labelText: 'اسم الزبون'),
              keyboardType: TextInputType.number,
              validator:
                  (value) => value!.isEmpty ? 'يجب ادخال اسم الزبون' : null,
            ),
            TextFormField(
              controller: _paidAmountController,
              decoration: InputDecoration(labelText: 'Paid Amount'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value!.isEmpty) return 'Paid amount is required';
                final paid = double.tryParse(value) ?? 0;
                if (paid <= 0) return 'Paid amount must be greater than 0';
                return null;
              },
            ),
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
              onChanged: (value) => setState(() => _selectedCurrency = value!),
              validator:
                  (value) => value == null ? 'Currency is required' : null,
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
              final currentDigitalCounter = double.parse(
                _digitalCounterController.text,
              );
              final customerName = _customerNameController.text;
              final pricePerLiter = double.parse(_pricePerLiterController.text);
              final paidAmount = double.parse(
                _paidAmountController.text,
              ); // Parse paidAmount
              final currency = _selectedCurrency;

              Navigator.pop(context, {
                'currentDigitalCounter': currentDigitalCounter,
                'pricePerLiter': pricePerLiter,
                'paidAmount': paidAmount, // Include paidAmount
                'currency': currency,
                'customerName': customerName,
              });
            }
          },
          child: Text('Sell Fuel'),
        ),
      ],
    );
  }
}
