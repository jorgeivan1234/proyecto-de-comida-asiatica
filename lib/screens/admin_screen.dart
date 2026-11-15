import 'package:flutter/material.dart';

import '../widgets/app_drawer.dart';
import '../widgets/navigation_bar.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: const SafeArea(
        child: Column(
          children: [
            AppNavigationBar(),
            Expanded(
              child: Center(
                child: Text(
                  'Permisos de administrador verificados. '
                  'El panel de gestión aún no está implementado.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
