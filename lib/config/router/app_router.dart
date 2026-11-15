import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/admin_screen.dart';
import '../../screens/screens.dart';
import '../../models/product.dart';
import '../../widgets/role_gate.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/catalog',
      builder: (context, state) => const CatalogScreen(),
    ),

    GoRoute(
      path: '/details_product',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! Product) {
          return const Scaffold(
            body: Center(child: Text('No se encontró el producto solicitado.')),
          );
        }

        return ProductDetailsScreen(product: extra);
      },
    ),
    GoRoute(path: '/orders', builder: (context, state) => const OrdersScreen()),
    GoRoute(
      path: '/admin',
      builder: (context, state) =>
          const RoleGate(requiredRole: 'admin', child: AdminScreen()),
    ),

    GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
  ],
);
