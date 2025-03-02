import 'package:cloud_backup/screens/home_screen.dart';
import 'package:cloud_backup/screens/account_setup_screen.dart';
import 'package:cloud_backup/screens/backup_status_screen.dart';
import 'package:cloud_backup/screens/settings_screen.dart';
import 'package:cloud_backup/services/preferences_service.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await PreferencesService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Backup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/account': (context) => const AccountSetupScreen(),
        '/status': (context) => const BackupStatusScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
