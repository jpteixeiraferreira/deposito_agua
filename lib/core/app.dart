import 'package:flutter/material.dart';
import 'routes.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: dotenv.env['APP_TITLE'] ?? 'App',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
