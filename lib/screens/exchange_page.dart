import 'package:flutter/material.dart';
import 'package:fuel_station_app/database_helper.dart';
import 'package:fuel_station_app/models/cashbox.dart';

class ExchangePage extends StatefulWidget {
  @override
  _ExchangePageState createState() => _ExchangePageState();
}

class _ExchangePageState extends State<ExchangePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TextEditingController _usdToSypController = TextEditingController();
  final TextEditingController _usdToTryController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  // Dynamic exchange rates
  double _usdToSypRate = 0.0;
  double _usdToTryRate = 0.0;

  String _sourceCurrency = 'USD';
  String _targetCurrency = 'SYP';
  double _resultAmount = 0.0;

  @override
  void dispose() {
    _usdToSypController.dispose();
    _usdToTryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // Calculate all exchange rates dynamically
  Map<String, double> getExchangeRates() {
    if (_usdToSypRate <= 0 || _usdToTryRate <= 0) {
      return {};
    }

    // Base rates
    final usdToSyp = _usdToSypRate;
    final usdToTry = _usdToTryRate;

    // Reverse rates
    final sypToUsd = 1 / usdToSyp;
    final tryToUsd = 1 / usdToTry;

    // Cross rates
    final sypToTry = usdToTry / usdToSyp;
    final tryToSyp = usdToSyp / usdToTry;

    return {
      'USD to SYP': usdToSyp,
      'USD to TRY': usdToTry,
      'SYP to USD': sypToUsd,
      'TRY to USD': tryToUsd,
      'SYP to TRY': sypToTry,
      'TRY to SYP': tryToSyp,
    };
  }

  // Get the exchange rate for the selected source and target currencies
  double getSelectedExchangeRate() {
    final rates = getExchangeRates();
    final key = '$_sourceCurrency to $_targetCurrency';
    return rates[key] ?? 0.0;
  }

  Future<void> _performExchange() async {
    final amount = double.tryParse(_amountController.text);
    final exchangeRate = getSelectedExchangeRate();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    if (exchangeRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid exchange rate. Please check your inputs.'),
        ),
      );
      return;
    }

    // Calculate the result amount
    final resultAmount = amount * exchangeRate;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Exchange'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Source Currency: $_sourceCurrency'),
                Text('Target Currency: $_targetCurrency'),
                Text('Amount to Exchange: $amount $_sourceCurrency'),
                Text(
                  'Result: ${resultAmount.toStringAsFixed(2)} $_targetCurrency',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Cancel
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true), // Confirm
                child: Text('Confirm'),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      // User canceled the exchange
      return;
    }

    // Proceed with the exchange
    try {
      // Check if the cashbox has sufficient balance in the source currency
      final cashboxMaps = await _dbHelper.queryAll('cashbox');
      if (cashboxMaps.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cashbox data not available')));
        return;
      }

      final cashbox = Cashbox.fromMap(cashboxMaps.first);
      double sourceBalance = 0.0;

      if (_sourceCurrency == 'USD') {
        sourceBalance = cashbox.usd;
      } else if (_sourceCurrency == 'SYP') {
        sourceBalance = cashbox.syp;
      } else if (_sourceCurrency == 'TRY') {
        sourceBalance = cashbox.tryCurrency;
      }

      if (amount > sourceBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient balance in the source currency'),
          ),
        );
        return;
      }

      // Deduct the source amount and add the target amount to the cashbox
      double usd = cashbox.usd;
      double syp = cashbox.syp;
      double tryCurrency = cashbox.tryCurrency;

      if (_sourceCurrency == 'USD') {
        usd -= amount;
      } else if (_sourceCurrency == 'SYP') {
        syp -= amount;
      } else if (_sourceCurrency == 'TRY') {
        tryCurrency -= amount;
      }

      if (_targetCurrency == 'USD') {
        usd += resultAmount;
      } else if (_targetCurrency == 'SYP') {
        syp += resultAmount;
      } else if (_targetCurrency == 'TRY') {
        tryCurrency += resultAmount;
      }

      final updatedCashbox = Cashbox(
        usd: usd,
        syp: syp,
        tryCurrency: tryCurrency,
      );
      final updatedMap = updatedCashbox.toMap();
      updatedMap['id'] = 1; // Ensure the ID is included
      await _dbHelper.update('cashbox', updatedMap);

      // Record the exchange as a transaction
      final transactionData = {
        'currency': _sourceCurrency,
        'amount': amount,
        'type': 'Exchange',
        'date': DateTime.now().toIso8601String(),
        'note':
            'Exchanged $amount $_sourceCurrency to $resultAmount $_targetCurrency',
      };
      await _dbHelper.insert('transactions', transactionData);

      // Reload data and show success message
      _amountController.clear();
      setState(() {
        _resultAmount = resultAmount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exchange completed successfully')),
      );
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to perform exchange: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Currency Exchange'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue[900],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // USD to SYP Rate Input
                Text(
                  'Exchange Rate (USD to SYP):',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _usdToSypController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.attach_money),
                    labelText: 'Enter rate (e.g., 8000)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _usdToSypRate = double.tryParse(value) ?? 0.0;
                    });
                  },
                ),
                SizedBox(height: 16),

                // USD to TRY Rate Input
                Text(
                  'Exchange Rate (USD to TRY):',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _usdToTryController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.attach_money),
                    labelText: 'Enter rate (e.g., 30)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _usdToTryRate = double.tryParse(value) ?? 0.0;
                    });
                  },
                ),
                SizedBox(height: 16),

                // Display All Exchange Rates
                Text(
                  'Calculated Exchange Rates:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                ...getExchangeRates().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${entry.key}:'),
                        Text('${entry.value.toStringAsFixed(4)}'),
                      ],
                    ),
                  );
                }).toList(),
                SizedBox(height: 16),

                // Source Currency
                Text(
                  'Source Currency:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _sourceCurrency,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _sourceCurrency = value!;
                    });
                  },
                  items:
                      ['USD', 'SYP', 'TRY'].map((currency) {
                        return DropdownMenuItem<String>(
                          value: currency,
                          child: Row(
                            children: [
                              Icon(Icons.monetization_on, color: Colors.green),
                              SizedBox(width: 8),
                              Text(currency),
                            ],
                          ),
                        );
                      }).toList(),
                ),
                SizedBox(height: 16),

                // Target Currency
                Text(
                  'Target Currency:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _targetCurrency,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.currency_exchange),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _targetCurrency = value!;
                    });
                  },
                  items:
                      ['USD', 'SYP', 'TRY'].map((currency) {
                        return DropdownMenuItem<String>(
                          value: currency,
                          child: Row(
                            children: [
                              Icon(Icons.monetization_on, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(currency),
                            ],
                          ),
                        );
                      }).toList(),
                ),
                SizedBox(height: 16),

                // Amount Input
                Text(
                  'Amount to Exchange:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.attach_money),
                    labelText: 'Enter amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),

                // Perform Exchange Button
                ElevatedButton.icon(
                  onPressed: _performExchange,
                  icon: Icon(Icons.currency_exchange),
                  label: Text('Perform Exchange'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    backgroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Result Display
                if (_resultAmount > 0)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Result: ${_resultAmount.toStringAsFixed(2)} $_targetCurrency',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
