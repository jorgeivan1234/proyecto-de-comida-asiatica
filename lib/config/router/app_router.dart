import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/screens.dart';
import '../../models/product.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    
    GoRoute(
      path: '/details_product',
      builder: (context, state){
        final extra = state.extra;
        if (extra is! Product) {
          return const Scaffold(
            body: Center(
              child: Text('No se encontró el producto solicitado.'),
            ),
          );
        }

        return ProductDetailsScreen(
          product: extra,
        );
      },
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrdersScreen(),
    ),

    GoRoute(
      path: '/cart',
      builder: (context, state) => const CartScreen(),
    ),
  ]
);
