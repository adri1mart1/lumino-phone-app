import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'lumino_pages.dart';

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const StartPage();
      },
    ),
    GoRoute(
      path: '/control',
      builder: (BuildContext context, GoRouterState state) {
        return const ControlPage();
      },
    ),
  ],
);

void main() {
  runApp(const LuminoApp());
}

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
      routerConfig: _router,
    );
  }
}
