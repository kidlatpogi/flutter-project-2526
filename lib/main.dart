import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';
import 'routing/route_names.dart';

/// Supabase configuration
const String supabaseUrl = 'https://krbcgixttxxdofdmevyj.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtyYmNnaXh0dHh4ZG9mZG1ldnlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY4MzYzNjgsImV4cCI6MjA1MjQxMjM2OH0.g6K0prOJF-7hoKZWSp1kYi8cqPWIDhG6E5MSr7-j_xM';

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bigkas',
      theme: AppTheme.theme,
      initialRoute: RouteNames.splash1,
      onGenerateRoute: AppRouter.generateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}