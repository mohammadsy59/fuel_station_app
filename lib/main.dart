import 'package:flutter/material.dart';
import 'package:fuel_station_app/screens/debts_screen.dart';
import 'package:fuel_station_app/screens/exchange_page.dart';
import 'package:fuel_station_app/screens/invoices_screen.dart';
import 'package:fuel_station_app/screens/lock_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Import sqflite_common_ffi
import 'screens/dashboard_screen.dart';
import 'screens/tanks_screen.dart';
import 'screens/pumps_screen.dart';
import 'screens/cashbox_screen.dart';

void main() async {
  // Initialize FFI for sqflite on desktop platforms
  WidgetsFlutterBinding.ensureInitialized();

  // Check if the platform is desktop (Windows, macOS, Linux)
  if (true) {
    // You can conditionally check for desktop platforms if needed
    sqfliteFfiInit(); // Initialize FFI
    databaseFactory = databaseFactoryFfi; // Set the database factory
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fuel Station Management',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LockScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    DashboardScreen(),
    TanksScreen(),
    PumpsScreen(),
    CashboxScreen(),
    InvoicesScreen(), // Add Invoices Screen
    DebtsScreen(),
    ExchangePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_gas_station),
            label: 'Tanks',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.ev_station), label: 'Pumps'),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Cashbox',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Invoices'),
          BottomNavigationBarItem(icon: Icon(Icons.money_off), label: 'Debts'),
          BottomNavigationBarItem(
            icon: Icon(Icons.currency_exchange),
            label: 'Exchange',
          ),
        ],
      ),
    );
  }
}
