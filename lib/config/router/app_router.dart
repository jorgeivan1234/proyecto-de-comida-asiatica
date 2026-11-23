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

    GoRoute(
      path: '/admin/orders',
      builder: (context, state) =>
          const RoleGate(requiredRole: 'admin', child: AdminOrdersScreen()),
    ),

    GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),

    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),

    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    GoRoute(
      path: '/almuerzos',
      builder: (context, state) => const CategoryProductsScreen(
        title: 'Almuerzos',
        categoryKeyword: 'almuerzo',
      ),
    ),

    GoRoute(
      path: '/dulces',
      builder: (context, state) => const CategoryProductsScreen(
        title: 'Dulces',
        categoryKeyword: 'dulce',
      ),
    ),
    GoRoute(
      path: '/descuentos',
      builder: (context, state) => const CategoryProductsScreen(
        title: 'Descuentos',
        categoryKeyword: 'descuento',
      ),
    ),

    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyScreen(),
    ),

    GoRoute(
      path: '/terms',
      builder: (context, state) => const TermsScreen(),
    ),

    GoRoute(
      path: '/order-tracking/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return OrderTrackingScreen(orderId: id);
      },
    ),
  ],
);
