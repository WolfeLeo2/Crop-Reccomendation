import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/service_locator.dart';
import 'features/crop_recommendation/presentation/pages/home_page.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  setupServiceLocator();
  runApp(const FarmWiseApp());
}

class FarmWiseApp extends StatelessWidget {
  const FarmWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmWise',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const HomePage(),
    );
  }
}
