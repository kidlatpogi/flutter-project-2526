import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';
import 'features/auth/screens/auth_wrapper.dart';
import 'features/auth/screens/reset_password_screen.dart';

/// Supabase configuration
const String supabaseUrl = 'https://krbcgixttxxdofdmevyj.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtyYmNnaXh0dHh4ZG9mZG1ldnlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1MDkxMDcsImV4cCI6MjA4NTA4NTEwN30.KY-H30jPK7KUu6tyTYGaLAicqIANL1cNCqvKaUnx_l8';

Future<void> main() async {
  // Enable clean URLs (without #) for better Supabase Auth compatibility
  usePathUrlStrategy();

  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with deep link configuration for OAuth
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: kIsWeb ? AuthFlowType.implicit : AuthFlowType.pkce,
    ),
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
      home: const AuthWrapper(),
      onGenerateRoute: AppRouter.generateRoute,
      onUnknownRoute: (settings) {
        // Handle unknown routes - OAuth redirects have access_token in URL fragment
        final routeName = settings.name ?? '';
        print('Unknown route: $routeName');
        
        // Check for password reset type parameter (type=recovery)
        if (routeName.contains('type=recovery') || routeName.contains('recovery')) {
          print('Password recovery callback detected');
          // Import and navigate to reset password screen
          return MaterialPageRoute(
            builder: (_) => const ResetPasswordScreen(),
          );
        }
        
        // OAuth callback URLs - the entire fragment becomes the route name
        // Check if route contains ANY OAuth-related parameter
        if (routeName.isEmpty || 
            routeName.contains('access_token') || 
            routeName.contains('provider_token') ||
            routeName.contains('refresh_token') ||
            routeName.contains('expires_at') ||
            routeName.contains('expires_in') ||
            routeName.contains('token_type') ||
            routeName.contains('code=') ||
            routeName.contains('error=') ||
            routeName.startsWith('#') ||
            routeName.startsWith('access_token=')) {
          print('OAuth callback detected, routing to AuthWrapper');
          // Return AuthWrapper which will check auth state and route accordingly
          return MaterialPageRoute(builder: (_) => const AuthWrapper());
        }
        
        // For other unknown routes, show error
        print('Showing error for unknown route: $routeName');
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('No route defined for ${settings.name}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}