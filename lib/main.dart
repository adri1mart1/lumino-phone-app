// main.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'lumino_pages.dart'; // Import the file containing your pages

// 1. Define the GoRouter configuration
final GoRouter _router = GoRouter(
  initialLocation: '/', // Start on the StartPage
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const StartPage(); // Route for the first page
      },
    ),
    GoRoute(
      path: '/control',
      builder: (BuildContext context, GoRouterState state) {
        return const ControlPage(); // Route for the second page
      },
    ),
  ],
);

// 2. Main function to run the app
void main() {
  runApp(const LuminoApp());
}

// 3. Main Application Widget
class LuminoApp extends StatelessWidget {
  const LuminoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lumino Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: false, // Ensure compatibility with older Android
      ),
      routerConfig: _router, // Use the router configuration
    );
  }
}
