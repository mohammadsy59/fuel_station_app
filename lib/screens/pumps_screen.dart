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
            title: Text('Confirm Delete'),
            content: Text('Are you sure you want to delete this pump?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete'),
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
      ).showSnackBar(SnackBar(content: Text('Pump deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete pump: $e')));
    }
  }

  Future<void> _sellFuel(Pump pump) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SellFuelDialog(pump: pump),
    );

    if (result != null) {
      try {
        // Extract input values
        final currentDigitalCounter = double.parse(result['digitalCounter']);
        final currentMechanicalCounter = double.parse(
          result['mechanicalCounter'],
        );
        final pricePerLiter = double.parse(result['pricePerLiter']);
        final employeeName = result['employeeName'];
        final currency = result['currency'];

        // Fetch the pump's previous readings
        final pumpMap = await _dbHelper.query(
          'pumps',
          where: 'id = ?',
          whereArgs: [pump.id],
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
        _loadData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fuel sold successfully!')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to sell fuel: $e')));
      }
    }
  }

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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Define PumpFormDialog
class PumpFormDialog extends StatefulWidget {
  final Pump? pump;
  final List<Map<String, dynamic>> tanks;
  final List<Pump> pumps;

  PumpFormDialog({this.pump, required this.tanks, required this.pumps});

  @override
  _PumpFormDialogState createState() => _PumpFormDialogState();
}

class _PumpFormDialogState extends State<PumpFormDialog> {
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

    _idController = TextEditingController(text: widget.pump?.id ?? '');
    _digitalCounterController = TextEditingController(
      text: widget.pump?.digitalCounter.toString() ?? '',
    );
    _mechanicalCounterController = TextEditingController(
      text: widget.pump?.mechanicalCounter.toString() ?? '',
    );
    _selectedTankId = widget.pump?.connectedTankId ?? widget.tanks.first['id'];
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
              validator:
                  (value) => value!.isEmpty ? 'Pump ID is required' : null,
            ),
            DropdownButtonFormField<String>(
              value: _selectedTankId,
              decoration: InputDecoration(labelText: 'Connected Tank'),
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
                      value == null ? 'Connected tank is required' : null,
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
                final existingPump = await DatabaseHelper.instance.query(
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

// Define SellFuelDialog
class SellFuelDialog extends StatefulWidget {
  final Pump pump;

  SellFuelDialog({required this.pump});

  @override
  _SellFuelDialogState createState() => _SellFuelDialogState();
}

class _SellFuelDialogState extends State<SellFuelDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _digitalCounterController;
  late TextEditingController _mechanicalCounterController;
  late TextEditingController _pricePerLiterController;
  late TextEditingController _employeeNameController;
  late String _selectedCurrency;

  @override
  void initState() {
    super.initState();

    _digitalCounterController = TextEditingController(
      text: widget.pump.digitalCounter.toString(),
    );
    _mechanicalCounterController = TextEditingController(
      text: widget.pump.mechanicalCounter.toString(),
    );
    _pricePerLiterController = TextEditingController();
    _employeeNameController = TextEditingController();
    _selectedCurrency = 'USD'; // Default currency
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
      title: Text('Sell Fuel'),
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
              decoration: InputDecoration(labelText: 'Price Per Liter'),
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
              final result = {
                'digitalCounter': _digitalCounterController.text,
                'mechanicalCounter': _mechanicalCounterController.text,
                'pricePerLiter': _pricePerLiterController.text,
                'employeeName': _employeeNameController.text,
                'currency': _selectedCurrency,
              };
              Navigator.pop(context, result);
            }
          },
          child: Text('Sell Fuel'),
        ),
      ],
    );
  }
}
