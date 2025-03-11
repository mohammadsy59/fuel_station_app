import 'package:flutter/material.dart';
import 'package:fuel_station_app/models/cashbox.dart';
import 'package:fuel_station_app/models/pump.dart';
import 'package:fuel_station_app/database_helper.dart';
import 'package:fuel_station_app/models/tank.dart';

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
          (context) => PumpFormDialog(
            pump: pump,
            tanks: _tanks,
            pumps: _pumps, // Pass the list of pumps
          ),
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
    await _dbHelper.database.then(
      (db) => db.delete('pumps', where: 'id = ?', whereArgs: [id]),
    );
    _loadData(); // Refresh the list
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fuel Pumps'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _addOrUpdatePump(),
          ),
        ],
      ),
      body:
          _pumps.isEmpty
              ? Center(child: Text('No pumps available.'))
              : ListView.builder(
                itemCount: _pumps.length,
                itemBuilder: (context, index) {
                  final pump = _pumps[index];
                  return _buildPumpCard(pump);
                },
              ),
    );
  }

  Future<void> _sellFuel(Pump pump) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SellFuelDialog(pump: pump),
    );

    if (result != null) {
      try {
        // Extract input values
        final digitalCounter = result['digitalCounter'];
        final mechanicalCounter = result['mechanicalCounter'];
        final pricePerLiter = result['pricePerLiter'];
        final employeeName = result['employeeName'];
        final currency = result['currency'];

        // Calculate fuel sold
        final fuelSold = digitalCounter - pump.digitalCounter;

        // Fetch the connected tank
        final tankMap = await _dbHelper.query(
          'tanks',
          where: 'id = ?',
          whereArgs: [pump.connectedTankId],
        );
        if (tankMap.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Connected tank not found!')));
          return;
        }
        final tank = Tank.fromMap(tankMap.first);

        // Check if there's enough fuel in the tank
        if (tank.currentLevel < fuelSold) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Not enough fuel in the tank!')),
          );
          return;
        }

        // Update tank's current level
        final updatedTank = tank.copyWith(
          currentLevel: tank.currentLevel - fuelSold,
        );
        await _dbHelper.update('tanks', updatedTank.toMap());

        // Update cashbox
        final cashboxMaps = await _dbHelper.queryAll('cashbox');
        Cashbox cashbox;
        if (cashboxMaps.isNotEmpty) {
          cashbox = Cashbox.fromMap(cashboxMaps.first);
        } else {
          cashbox = Cashbox(usd: 0, syp: 0, tryCurrency: 0);
        }

        final revenue = fuelSold * pricePerLiter;
        if (currency == 'USD') {
          cashbox = cashbox.copyWith(usd: cashbox.usd + revenue);
        } else if (currency == 'SYP') {
          cashbox = cashbox.copyWith(syp: cashbox.syp + revenue);
        } else if (currency == 'TRY') {
          cashbox = cashbox.copyWith(
            tryCurrency: cashbox.tryCurrency + revenue,
          );
        }
        await _dbHelper.insertOrUpdateCashbox(cashbox);

        // Update pump counters
        final updatedPump = pump.copyWith(
          digitalCounter: digitalCounter,
          mechanicalCounter: mechanicalCounter,
        );
        await _dbHelper.update('pumps', updatedPump.toMap());

        // Create an invoice
        final invoice = {
          'pumpId': pump.id,
          'fuelSold': fuelSold,
          'pricePerLiter': pricePerLiter,
          'totalRevenue': revenue,
          'currency': currency,
          'employeeName': employeeName,
          'timestamp': DateTime.now().toIso8601String(),
        };
        await _dbHelper.insert('invoices', invoice);

        // Refresh data
        _loadData();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fuel sold successfully!')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to sell fuel: $e')));
        print(e);
      }
    }
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
              'Pump ${pump.id}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Connected to Tank: ${pump.connectedTankId}'),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Digital Counter: ${pump.digitalCounter}L'),
                Text('Mechanical Counter: ${pump.mechanicalCounter}L'),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _sellFuel(pump),
                  icon: Icon(Icons.sell),
                  label: Text('Sell Fuel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PumpFormDialog extends StatefulWidget {
  final Pump? pump;
  final List<Map<String, dynamic>> tanks;
  final List<Pump> pumps; // Add a list of existing pumps

  PumpFormDialog({
    this.pump,
    required this.tanks,
    required this.pumps, // Pass the list of pumps
  });

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

  bool _isEditMode = false; // Track if we're editing an existing pump

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
      title: Text(widget.pump == null ? 'Add Pump' : 'Edit Pump'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _idController,
              decoration: InputDecoration(labelText: 'Pump ID'),
              enabled: !_isEditMode, // Disable ID field in edit mode
              validator: (value) {
                if (_isEditMode && value!.isEmpty) {
                  return 'ID is required';
                }
                if (!RegExp(r'^P\d+$').hasMatch(value!)) {
                  return 'ID must start with "P" followed by a number (e.g., P1, P2)';
                }
                return null;
              },
            ),
            DropdownButtonFormField<String>(
              value: _selectedTankId,
              decoration: InputDecoration(labelText: 'Connected Tank'),
              items:
                  widget.tanks.map((tank) {
                    return DropdownMenuItem<String>(
                      value: tank['id'],
                      child: Text('${tank['fuelType']} Tank (${tank['id']})'),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTankId = value!;
                });
              },
              validator: (value) => value == null ? 'Tank is required' : null,
            ),
            TextFormField(
              controller: _digitalCounterController,
              decoration: InputDecoration(labelText: 'Digital Counter (L)'),
              keyboardType: TextInputType.number,
              validator:
                  (value) =>
                      value!.isEmpty ? 'Digital counter is required' : null,
            ),
            TextFormField(
              controller: _mechanicalCounterController,
              decoration: InputDecoration(labelText: 'Mechanical Counter (L)'),
              keyboardType: TextInputType.number,
              validator:
                  (value) =>
                      value!.isEmpty ? 'Mechanical counter is required' : null,
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
                    SnackBar(content: Text('Pump ID already exists!')),
                  );
                  return;
                }
              }

              Navigator.pop(context, pumpData);
            }
          },
          child: Text(widget.pump == null ? 'Add' : 'Save'),
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
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _digitalCounterController;
  late TextEditingController _mechanicalCounterController;
  late TextEditingController _pricePerLiterController;
  late TextEditingController _employeeNameController;
  String _selectedCurrency = 'USD'; // Default currency
  String _paymentStatus = 'Paid'; // Default payment status
  double _calculateSoldFuel(
    double previousDigitalCounter,
    double currentDigitalCounter,
    double previousMechanicalCounter,
    double currentMechanicalCounter,
  ) {
    const maxDigitalValue = 9999; // Maximum value of the digital counter

    // Calculate the number of full cycles the digital counter has completed
    final mechanicalCycles =
        currentMechanicalCounter - previousMechanicalCounter;

    // Calculate the difference in the digital counter
    double digitalDifference;
    if (currentDigitalCounter < previousDigitalCounter) {
      // Digital counter has reset
      digitalDifference =
          (maxDigitalValue - previousDigitalCounter) + currentDigitalCounter;
    } else {
      // No reset occurred
      digitalDifference = currentDigitalCounter - previousDigitalCounter;
    }

    // Total fuel sold = (mechanical cycles * maxDigitalValue) + digitalDifference
    return (mechanicalCycles * maxDigitalValue) + digitalDifference;
  }

  @override
  void initState() {
    super.initState();

    // Initialize controllers with pump's current values
    _digitalCounterController = TextEditingController(
      text: widget.pump.digitalCounter.toString(),
    );
    _mechanicalCounterController = TextEditingController(
      text: widget.pump.mechanicalCounter.toString(),
    );
    _pricePerLiterController = TextEditingController();
    _employeeNameController = TextEditingController();
  }

  @override
  void dispose() {
    _digitalCounterController.dispose();
    _mechanicalCounterController.dispose();
    _pricePerLiterController.dispose();
    _employeeNameController.dispose();
    super.dispose();
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
              controller: _mechanicalCounterController,
              decoration: InputDecoration(labelText: 'Mechanical Counter (L)'),
              keyboardType: TextInputType.number,
              validator:
                  (value) =>
                      value!.isEmpty ? 'Mechanical counter is required' : null,
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
              controller: _employeeNameController,
              decoration: InputDecoration(labelText: 'Employee Name'),
              validator:
                  (value) =>
                      value!.isEmpty ? 'Employee name is required' : null,
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
              onChanged: (value) {
                setState(() {
                  _selectedCurrency = value!;
                });
              },
              validator:
                  (value) => value == null ? 'Currency is required' : null,
            ),
            DropdownButtonFormField<String>(
              value: _paymentStatus,
              decoration: InputDecoration(labelText: 'Payment Status'),
              items:
                  ['Paid', 'Unpaid'].map((status) {
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
              validator:
                  (value) =>
                      value == null ? 'Payment status is required' : null,
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
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              try {
                // Extract input values
                final currentDigitalCounter = double.parse(
                  _digitalCounterController.text,
                );
                final currentMechanicalCounter = double.parse(
                  _mechanicalCounterController.text,
                );
                final pricePerLiter = double.parse(
                  _pricePerLiterController.text,
                );
                final employeeName = _employeeNameController.text;
                final currency = _selectedCurrency;

                // Fetch the pump's previous readings
                final pumpMap = await _dbHelper.query(
                  'pumps',
                  where: 'id = ?',
                  whereArgs: [widget.pump.id],
                );
                if (pumpMap.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Pump not found!')));
                  return;
                }
                final previousDigitalCounter =
                    pumpMap.first['digitalCounter'] as double;
                final previousMechanicalCounter =
                    pumpMap.first['mechanicalCounter'] as double;

                // Calculate the total fuel sold
                final fuelSold = _calculateSoldFuel(
                  previousDigitalCounter,
                  currentDigitalCounter,
                  previousMechanicalCounter,
                  currentMechanicalCounter,
                );

                // Fetch the connected tank
                final tankMap = await _dbHelper.query(
                  'tanks',
                  where: 'id = ?',
                  whereArgs: [widget.pump.connectedTankId],
                );
                if (tankMap.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Connected tank not found!')),
                  );
                  return;
                }
                final tank = Tank.fromMap(tankMap.first);

                // Check if there's enough fuel in the tank
                if (tank.currentLevel < fuelSold) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Not enough fuel in the tank!')),
                  );
                  return;
                }

                // Update tank's current level
                final updatedTank = tank.copyWith(
                  currentLevel: tank.currentLevel - fuelSold,
                );
                await _dbHelper.update('tanks', updatedTank.toMap());

                // Update cashbox
                final cashboxMaps = await _dbHelper.queryAll('cashbox');
                Cashbox cashbox;
                if (cashboxMaps.isNotEmpty) {
                  cashbox = Cashbox.fromMap(cashboxMaps.first);
                } else {
                  cashbox = Cashbox(usd: 0, syp: 0, tryCurrency: 0);
                }

                final revenue = fuelSold * pricePerLiter;
                if (currency == 'USD') {
                  cashbox = cashbox.copyWith(usd: cashbox.usd + revenue);
                } else if (currency == 'SYP') {
                  cashbox = cashbox.copyWith(syp: cashbox.syp + revenue);
                } else if (currency == 'TRY') {
                  cashbox = cashbox.copyWith(
                    tryCurrency: cashbox.tryCurrency + revenue,
                  );
                }
                await _dbHelper.insertOrUpdateCashbox(cashbox);

                // Update pump counters
                final updatedPump = widget.pump.copyWith(
                  digitalCounter: currentDigitalCounter,
                  mechanicalCounter: currentMechanicalCounter,
                );
                await _dbHelper.update('pumps', updatedPump.toMap());

                // Create an invoice
                final invoice = {
                  'customerName': employeeName,
                  'fuelType': tank.fuelType,
                  'quantity': fuelSold,
                  'pricePerUnit': pricePerLiter,
                  'totalAmount': revenue,
                  'currency': currency,
                  'date': DateTime.now().toIso8601String(),
                  'paymentStatus': 'Paid',
                };
                await _dbHelper.insert('invoices', invoice);

                // Refresh data
                Navigator.pop(context); // Close the dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Fuel sold successfully!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to sell fuel: $e')),
                );
              }
            }
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}
