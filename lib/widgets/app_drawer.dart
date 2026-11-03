import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF90CAF9),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Chucherías',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            onTap: () => context.go('/home'),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_bag),
            title: const Text('Mis pedidos'),
            onTap: () => context.go('/orders'),
          ),
        ],
      ),
    );
  }
}
