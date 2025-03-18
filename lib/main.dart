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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'إدارة محطة الوقود',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: LockScreen(),
      ),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
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
              label: 'الشاشة الرئيسية ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_gas_station),
              label: 'الخزانات ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.ev_station),
              label: 'المضخات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.attach_money),
              label: 'الصندوق',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt),
              label: 'الفواتير',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.money_off),
              label: 'الديون',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.currency_exchange),
              label: 'الصرافة',
            ),
          ],
        ),
      ),
    );
  }
}
