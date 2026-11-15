import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_role_provider.dart';

class RoleGate extends StatelessWidget {
  const RoleGate({super.key, required this.requiredRole, required this.child});

  final String requiredRole;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<UserRoleProvider>(
      builder: (context, userRole, _) {
        if (userRole.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userRole.error != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No se pudo verificar tu rol: ${userRole.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: userRole.refresh,
                      child: const Text('Volver a intentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (userRole.role != requiredRole) {
          return const Scaffold(
            body: Center(child: Text('No tienes permiso para acceder.')),
          );
        }

        return child;
      },
    );
  }
}
