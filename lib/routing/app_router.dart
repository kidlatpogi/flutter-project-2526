import 'package:flutter/material.dart';
import '../features/splash/screens/splash_screen1.dart';
import '../features/splash/screens/splash_screen2.dart';
import '../features/splash/screens/splash_screen3.dart';
import 'route_names.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash1:
        return MaterialPageRoute(builder: (_) => const SplashScreen1());
      case RouteNames.splash2:
        return MaterialPageRoute(builder: (_) => const SplashScreen2());
      case RouteNames.splash3:
        return MaterialPageRoute(builder: (_) => const SplashScreen3());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}