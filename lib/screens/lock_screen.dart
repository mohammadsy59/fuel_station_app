import 'package:flutter/material.dart';
import 'package:fuel_station_app/database_helper.dart';
import 'package:fuel_station_app/main.dart';
import 'package:fuel_station_app/screens/dashboard_screen.dart';

class LockScreen extends StatefulWidget {
  @override
  _LockScreenState createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TextEditingController _passwordController = TextEditingController();
  bool _isLocked = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _validatePassword() async {
    final enteredPassword = _passwordController.text;

    // Fetch the stored password from the database
    final passwordMaps = await _dbHelper.queryAll('settings');
    if (passwordMaps.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('لا يوجد كلمة مرور اتصل بالمشرف')));
      return;
    }

    final storedPassword = passwordMaps.first['password'] as String?;

    if (enteredPassword == storedPassword) {
      setState(() {
        _isLocked = false;
      });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
      _passwordController.clear(); // Unlock the app
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('كلمة السر غير صحيحة الرجاء المحاولة مرة ثانية '),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent the user from going back when locked
        return !_isLocked;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('التطبيق مقفل '),
          centerTitle: true,
          backgroundColor: Colors.red[900],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 100, color: Colors.red[900]),
              SizedBox(height: 16),
              Text(
                'أدخل كلمة السر لفتح التطبيق ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'كلمة السر ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _validatePassword,
                icon: Icon(Icons.lock_open),
                label: Text('فتح القفل '),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.red[900],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
