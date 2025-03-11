import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fuel_station_app/database_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class ChangePasswordScreen extends StatefulWidget {
  final VoidCallback reloadData;

  ChangePasswordScreen({required this.reloadData});

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Controllers for password fields
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Method to change the password
  Future<void> _changePassword(BuildContext context) async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validate inputs
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please fill in all fields')));
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New password and confirm password do not match'),
        ),
      );
      return;
    }

    // Fetch the stored password from the database
    final passwordMaps = await _dbHelper.queryAll('settings');
    if (passwordMaps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No password set. Please contact the admin.')),
      );
      return;
    }

    final storedPassword = passwordMaps.first['password'] as String?;

    if (currentPassword != storedPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Incorrect current password')));
      return;
    }

    // Update the password in the database
    await _dbHelper.update('settings', {'id': 1, 'password': newPassword});

    // Clear the fields and show success message
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Password changed successfully')));
  }

  // Method to backup data
  Future<void> _backupData(BuildContext context) async {
    try {
      // Export data
      final data = await _dbHelper.exportData();

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/backup.json');
      await file.writeAsString(jsonEncode(data));

      // Optionally share the file
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Fuel Station App Backup');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup completed successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create backup: $e')));
    }
  }

  // Method to restore data
  Future<void> _restoreData(BuildContext context) async {
    try {
      // Load backup file
      final data = await _dbHelper.loadBackupFromFile();
      print('Loaded backup data: $data'); // Log the loaded data

      // Import data
      await _dbHelper.importData(data);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Data restored successfully')));
    } catch (e) {
      print('Error during restore: $e'); // Log the error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to restore data: $e')));
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Security Settings'),
        centerTitle: true,
        backgroundColor: Colors.blue[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Change Password Section
            Text(
              'Change Password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _changePassword(context),
              icon: Icon(Icons.save),
              label: Text('Save New Password'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.blue[900],
              ),
            ),

            // Backup and Restore Section
            SizedBox(height: 24),
            Text(
              'Backup and Restore',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _backupData(context),
                  icon: Icon(Icons.backup),
                  label: Text('Backup Data'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(150, 50),
                    backgroundColor: Colors.green[700],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _restoreData(context),
                  icon: Icon(Icons.restore),
                  label: Text('Restore Data'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(150, 50),
                    backgroundColor: Colors.orange[700],
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
