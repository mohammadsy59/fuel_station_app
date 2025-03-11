// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fuel_station_app/models/tank.dart';
import 'package:fuel_station_app/models/pump.dart';
import 'package:fuel_station_app/models/cashbox.dart';
import 'package:fuel_station_app/database_helper.dart';
import 'package:fuel_station_app/screens/change_password_screen.dart';
import 'package:fuel_station_app/screens/lock_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Tank> _tanks = [];
  List<Pump> _pumps = [];
  Cashbox? _cashbox;

  // Import file_picker

  // Define professional colors
  final Color usdColor = Color(0xFF4CAF50); // Green
  final Color sypColor = Color(0xFFFF9800); // Orange
  final Color tryColor = Color(0xFFE53935); // Red

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load tanks
    final tankMaps = await _dbHelper.queryAll('tanks');
    setState(() {
      _tanks = tankMaps.map((map) => Tank.fromMap(map)).toList();
    });

    // Load pumps
    final pumpMaps = await _dbHelper.queryAll('pumps');
    setState(() {
      _pumps = pumpMaps.map((map) => Pump.fromMap(map)).toList();
    });

    // Load cashbox
    final cashboxMaps = await _dbHelper.queryAll('cashbox');
    if (cashboxMaps.isNotEmpty) {
      setState(() {
        _cashbox = Cashbox.fromMap(cashboxMaps.first);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            ChangePasswordScreen(reloadData: _loadData),
                  ),
                ),
          ),
        ],
        title: Text('Fuel Station Dashboard'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadData();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Overview'),
              _buildOverviewSection(),
              SizedBox(height: 20),
              _buildSectionTitle('Fuel Tanks'),
              ..._tanks.map((tank) => _buildTankCard(tank)),
              SizedBox(height: 20),
              _buildSectionTitle('Pumps'),
              ..._pumps.map((pump) => _buildPumpCard(pump)),
              SizedBox(height: 20),
              _buildSectionTitle('Actions'),

              SizedBox(height: 20),
              Container(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LockScreen()),
                    );
                  },
                  icon: Icon(Icons.lock),
                  label: Text('Lock App'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    backgroundColor: Colors.blue[500],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              thickness: 1,
              color: Colors.grey.shade300,
              indent: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Container(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => SizedBox(width: 16),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildMetricCard(
              'USD',
              '\$${_cashbox?.usd.toStringAsFixed(2) ?? '0.00'}',
              usdColor,
            );
          } else if (index == 1) {
            return _buildMetricCard(
              'SYP',
              '${_cashbox?.syp.toStringAsFixed(2) ?? '0.00'}',
              sypColor,
            );
          } else {
            return _buildMetricCard(
              'TRY',
              '₺${_cashbox?.tryCurrency.toStringAsFixed(2) ?? '0.00'}',
              tryColor,
            );
          }
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
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
            Text(
              '${tank.fuelType} Tank (${tank.id})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Capacity: ${tank.capacity}L'),
                Text('Current: ${tank.currentLevel}L'),
              ],
            ),
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
                '${tank.percentageFilled.toStringAsFixed(1)}% Filled',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ],
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
          ],
        ),
      ),
    );
  }
}
