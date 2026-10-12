import 'package:ccomcercio_electronico/models/product.dart';
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
          final product = state.extra as Product;

          return ProductDetailsScreen(
            product: product, 
        );
      } 
    )
  ]
);

