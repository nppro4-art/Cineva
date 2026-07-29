import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/pages/admin_navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const CinevaAdminApp());
}

class CinevaAdminApp extends StatelessWidget {
  const CinevaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cineva Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AdminNavigation(),
    );
  }
}
