import 'package:flutter/material.dart';
import 'package:fuel_station_app/models/tank.dart';
import 'package:fuel_station_app/database_helper.dart';

class TanksScreen extends StatefulWidget {
  @override
  _TanksScreenState createState() => _TanksScreenState();
}

class _TanksScreenState extends State<TanksScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Tank> _tanks = [];

  @override
  void initState() {
    super.initState();
    _loadTanks();
  }

  Future<void> _loadTanks() async {
    final tankMaps = await _dbHelper.queryAll('tanks');
    setState(() {
      _tanks = tankMaps.map((map) => Tank.fromMap(map)).toList();
    });
  }

  Future<void> _addOrUpdateTank({Tank? tank}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TankFormDialog(tank: tank, tanks: _tanks),
    );

    if (result != null) {
      try {
        if (tank == null) {
          // Check for duplicate ID
          final existingTank = await _dbHelper.query(
            'tanks',
            where: 'id = ?',
            whereArgs: [result['id']],
          );
          if (existingTank.isNotEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('رقم الخزان موجود سابقاً!')));
            return;
          }
          await _dbHelper.insert('tanks', result);
        } else {
          await _dbHelper.update('tanks', result);
        }
        _loadTanks(); // Refresh the list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'الخزان  ${tank == null ? 'تم اللإضافة' : 'تم التعديل'} بنجاح',
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
      }
    }
  }

  Future<void> _deleteTank(String id) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تأكيد الحذف'),
            content: Text(
              'هل بالتأكيد نريد حذف الخزان! لا يمكن التراجع عن هذا الإجراء؟',
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

    // Proceed only if the user confirms
    if (shouldDelete != true) return;

    try {
      await _dbHelper.database.then(
        (db) => db.delete('tanks', where: 'id = ?', whereArgs: [id]),
      );
      _loadTanks(); // Refresh the list
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم حذف الخزان بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل حذف الخزان : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('خزانات الوقود'),
          actions: [
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () => _addOrUpdateTank(),
            ),
          ],
        ),
        body:
            _tanks.isEmpty
                ? Center(child: Text('لا يوجد خزانات !'))
                : ListView.builder(
                  itemCount: _tanks.length,
                  itemBuilder: (context, index) {
                    final tank = _tanks[index];
                    return _buildTankCard(tank);
                  },
                ),
      ),
    );
  }

  Widget _buildTankCard(Tank tank) {
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
                  '${tank.fuelType} الخزان (${tank.id})',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _addOrUpdateTank(tank: tank),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteTank(tank.id),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('السعة : ${tank.capacity}L'),
            Text('الكمية الموجودة: ${tank.currentLevel}L'),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: tank.percentageFilled / 100,
              backgroundColor: Colors.grey[300],
              color: Colors.blue,
            ),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${tank.percentageFilled.toStringAsFixed(1)}% ممتلئ',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TankFormDialog extends StatefulWidget {
  final Tank? tank;
  final List<Tank> tanks;

  TankFormDialog({this.tank, required this.tanks});

  @override
  _TankFormDialogState createState() => _TankFormDialogState();
}

class _TankFormDialogState extends State<TankFormDialog> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController;
  late TextEditingController _fuelTypeController;
  late TextEditingController _capacityController;
  late TextEditingController _currentLevelController;

  bool _isEditMode = false; // Track if we're editing an existing tank

  @override
  void initState() {
    super.initState();

    _isEditMode = widget.tank != null;

    // Initialize controllers
    _idController = TextEditingController(text: widget.tank?.id ?? '');
    _fuelTypeController = TextEditingController(
      text: widget.tank?.fuelType ?? '',
    );
    _capacityController = TextEditingController(
      text: widget.tank?.capacity.toString() ?? '',
    );
    _currentLevelController = TextEditingController(
      text: widget.tank?.currentLevel.toString() ?? '',
    );

    // Auto-generate ID for new tanks
    if (!_isEditMode) {
      _generateUniqueId();
    }
  }

  Future<void> _generateUniqueId() async {
    // Query the database for the highest existing ID
    final existingTanks = await _dbHelper.queryAll('tanks');
    int maxId = 0;

    for (var tank in existingTanks) {
      final id = tank['id'] as String;
      final numericPart =
          int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (numericPart > maxId) {
        maxId = numericPart;
      }
    }

    // Generate the next ID
    final nextId = 'T${maxId + 1}';
    _idController.text = nextId;
  }

  @override
  void dispose() {
    _idController.dispose();
    _fuelTypeController.dispose();
    _capacityController.dispose();
    _currentLevelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tank == null ? 'إضافة خزان' : 'تعديل خزان'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _idController,
              decoration: InputDecoration(labelText: 'رقم الخزان'),
              enabled: false, // Disable ID field in edit mode
              validator: (value) {
                if (_isEditMode && value!.isEmpty) {
                  return 'رقم الخزان مطلوب ';
                }
                if (!RegExp(r'^T\d+$').hasMatch(value!)) {
                  return 'ID must start with "T" followed by a number (e.g., T1, T2)';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _fuelTypeController,
              decoration: InputDecoration(labelText: 'نوع الوقود '),
              validator: (value) => value!.isEmpty ? 'نوع الوقود مطلوب ' : null,
            ),
            TextFormField(
              controller: _capacityController,
              decoration: InputDecoration(labelText: 'السعة باللتر  (L)'),
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty ? 'السعة مطلوبة' : null,
            ),
            TextFormField(
              controller: _currentLevelController,
              decoration: InputDecoration(labelText: 'الكمية الموجودة  (L)'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value!.isEmpty) {
                  return 'الكمية االموجودة مطلوبة ';
                }
                final currentLevel = double.tryParse(value);
                final capacity = double.tryParse(_capacityController.text);
                if (currentLevel != null &&
                    capacity != null &&
                    currentLevel > capacity) {
                  return 'الكمية الحالية أكبر من سعة الخزان';
                }
                return null;
              },
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
              final tankData = {
                'id': _idController.text,
                'fuelType': _fuelTypeController.text,
                'capacity': double.parse(_capacityController.text),
                'currentLevel': double.parse(_currentLevelController.text),
              };

              // Check for duplicate ID when adding a new tank
              if (!_isEditMode) {
                final existingTank = await _dbHelper.query(
                  'tanks',
                  where: 'id = ?',
                  whereArgs: [tankData['id']],
                );
                if (existingTank.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('رقم الخزان موجود سابقاً')),
                  );
                  return;
                }
              }

              Navigator.pop(context, tankData);
            }
          },
          child: Text(widget.tank == null ? 'إضافة ' : 'حفظ'),
        ),
      ],
    );
  }
}
