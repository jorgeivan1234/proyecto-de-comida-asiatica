import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/user_role_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF90CAF9)),
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
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('Catálogo'),
            onTap: () => context.go('/catalog'),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_bag),
            title: const Text('Mis pedidos'),
            onTap: () => context.go('/orders'),
          ),
          Consumer<UserRoleProvider>(
            builder: (context, userRole, _) {
              if (userRole.role != 'admin') {
                return const SizedBox.shrink();
              }

              return ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Administración'),
                onTap: () => context.go('/admin'),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              try {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              } on AuthException catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No se pudo cerrar sesión: ${error.message}'),
                  ),
                );
              }
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Aviso de Privacidad'),
            onTap: () => context.go('/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terminos y Condiciones'),
            onTap: () => context.go('/terms'),
          ),
        ],
      ),
    );
  }
}
