import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'modules/production/dashboard/screens/production_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Operonix Production',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ProductionEntryScreen(),
    );
  }
}

class ProductionEntryScreen extends StatelessWidget {
  const ProductionEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> companyData = {
      'companyId': 'test_company',
      'plantKey': 'test_plant',
      'userId': 'test_user',
    };

    return ProductionDashboardScreen(companyData: companyData);
  }
}
