import 'package:ccomcercio_electronico/config/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/cart_provider.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Comida asiatica',
        routerConfig: appRouter,
      ),
    );
  }
}
