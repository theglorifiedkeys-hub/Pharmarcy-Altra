import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app/theme.dart';
import 'features/workspace.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  runApp(const AltraApp());
}

class AltraApp extends StatelessWidget {
  const AltraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Altra Pharmacy',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    home: const Workspace(),
  );
}
