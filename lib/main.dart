import 'package:ccomcercio_electronico/config/router/app_router.dart';
import 'package:ccomcercio_electronico/screens/home_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Comida asiatica',
      routerConfig: appRouter,
    );
  }
}